//
//  ViewController.swift
//  gesture_sensor
//
//  Created by Andrew Wagenmaker on 4/22/20.
//  Copyright © 2020 Andrew Wagenmaker. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import CoreLocation

class ViewController: UIViewController, UIApplicationDelegate, AVAudioPlayerDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var gestureView: GestureView!
    
    let locationManager = CLLocationManager()
    let home_lat = 47.6530709
    let home_long = -122.3050338
    var left_home = false
    var alarm_sounded = false
    
    var timer = Timer()
  
    var audioInput: TempiAudioInput!
    var audioPlayer = AVAudioPlayer()
    let gesture_threshold: Float = 0.7
    let water_classifier = RunningWateriOS()
    let num_features = 40
    var projections: Array<Float> = Array(repeating: 0.0, count: 40*1024)
    var file_count = 0
    var last_time: Int64 = 0
    var audio_off = true
    var old_samples: Array<Float> = Array(repeating: 0.0, count: 2048)
    var app_start_time: Int64 = 0
    
    var previous_classes: Array<Int64> = Array(repeating: 0, count: 20)
    var previous_doppler: Array<Float> = Array(repeating: 0.0, count: 20)
    var previous_idx = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        let audioInputCallback: TempiAudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            self.gotSomeAudio(timeStamp: Double(timeStamp), numberOfFrames: Int(numberOfFrames), samples: samples)
            // uncomment the following and comment the above line to record data for training
            //self.gotSomeAudioRecord(timeStamp: Double(timeStamp), numberOfFrames: Int(numberOfFrames), samples: samples)
        }
        
        let test_sound = Bundle.main.path(forResource: "tone_18khz_amp", ofType: "wav")
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: test_sound!))
            audioPlayer.delegate = self
           
        } catch {
            
        }
        
        audioInput = TempiAudioInput(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        loadProj()
        app_start_time = Int64(NSDate().timeIntervalSince1970 * 1000)
    }
    
    func loadProj() {
        if let path = Bundle.main.path(forResource: "proj_weights_ios", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let myStrings = data.components(separatedBy: .newlines)
                for i in 0...(num_features*1024-1) {
                    projections[i] = Float(myStrings[i]) ?? 0.0
                }
            } catch {
                print(error)
            }
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if alarm_sounded == false {
            audioPlayer.play()
        }
    }

    func gotSomeAudio(timeStamp: Double, numberOfFrames: Int, samples: [Float]) {
        let time = Int64(NSDate().timeIntervalSince1970 * 1000)
        if time - last_time > 400 && time - last_time < 1100 && audio_off {
            audio_off = false
            old_samples = samples
            audioPlayer.setVolume(0.0, fadeDuration: 0.25)
        }
        if time - last_time > 1100 {
            audio_off = true
            last_time = time
            let fft = TempiFFT(withSize: 2048, sampleRate: 44100.0)
            fft.windowType = TempiFFTWindowType.hamming
            var normalizer: Float = 0.0
            for i in 0...(2048-1) {
                normalizer += old_samples[i]*old_samples[i]
            }
            normalizer = sqrt(normalizer)
            var normalized_samples: Array<Float> = Array(repeating: 0.0, count: 2048)
            for i in 0...(2048-1) {
                normalized_samples[i] = old_samples[i] / normalizer
            }
            fft.fftForward(normalized_samples)
            var features = projFFT(fft_amps: fft.getMagnitudes())

            guard let features2 = try? MLMultiArray(shape:[NSNumber(value: num_features)], dataType:MLMultiArrayDataType.double) else {
                fatalError("Unexpected runtime error. MLMultiArray")
            }
            for i in 0...(num_features-1) {
                features2[i] = NSNumber(floatLiteral: Double(features[i]))
            }
            let input = RunningWateriOSInput(input: features2)
            
            do {
                let output = try water_classifier.prediction(input: input)
                let label = output.classLabel
                let side_mag = fft.side_mags()
                
                previous_classes[previous_idx] = label
                previous_doppler[previous_idx] = side_mag
                previous_idx += 1
                if previous_idx >= 20 {
                    previous_idx = 0
                }
                
                var class_count = 0
                var doppler_count = 0
                for i in 0...19 {
                    class_count += Int(previous_classes[i])
                    if previous_doppler[i] > gesture_threshold {
                        doppler_count += 1
                    }
                }
                var washed_str = ""
                if class_count > 5 && doppler_count > 10 {
                    self.timer.invalidate()
                    audioInput.stopRecording()
                    audioPlayer.stop()
                    washed_str = "Washed"
                }
                
                tempi_dispatch_main { () -> () in
                    self.gestureView.freqLabelStr = washed_str
                    self.gestureView.setNeedsDisplay()
                }
            } catch {
                print(error)
            }
        }
        if time - last_time > 200 && time - last_time < 400 {
            audioPlayer.setVolume(1.0, fadeDuration: 0.1)
        }
    }
    
    
    func projFFT(fft_amps: [Float]) -> [Float] {
        var features: Array<Float> = Array(repeating: 0.0, count: num_features)
        for i in 0...(num_features-1) {
            for j in 0...1023 {
                features[i] += fft_amps[j]*projections[j+i*1024]
            }
        }
        return features
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        distanceFromHome(lat: locValue.latitude, long: locValue.longitude)
    }
    
    
    func distanceFromHome(lat: Double, long: Double) {
        let PI = 3.141592653589793
        
        let radlat1 = PI * lat / 180.0
        let radlat2 = PI * home_lat / 180.0
        
        let theta = long - home_long
        let radtheta = PI * theta / 180.0
        
        var dist = sin(radlat1) * sin(radlat2) + cos(radlat1)*cos(radlat2)*cos(radtheta)
    
        if dist > 1 {
            dist = 1
        }
        
        dist = acos(dist)
        dist = dist * 180.0 / PI
        dist = dist * 60.0 * 1.1515
        
        let time = Int64(NSDate().timeIntervalSince1970 * 1000)
        if dist > 0.1 && left_home == false && time - app_start_time > 60000 {
            left_home = true
        }
        if left_home && dist < 0.03 {
            left_home = false

            self.timer = Timer.scheduledTimer(timeInterval: 5.0*60.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
            
            alarm_sounded = false
            audioPlayer.play()
            audioInput.startRecording()
        }
    }
    
    
    @objc func fireTimer() {
        print("Timer fired!")
        alarm_sounded = true
        timer.invalidate()
        
        audioInput.stopRecording()
        audioPlayer.stop()
        let test_sound = Bundle.main.path(forResource: "railroad", ofType: "m4a")
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: test_sound!))
            audioPlayer.delegate = self
           
        } catch {
            
        }
        audioPlayer.play()
    }
    
    
    
    // The following functions are used in recording more training data
    func gotSomeAudioRecord(timeStamp: Double, numberOfFrames: Int, samples: [Float]) {
        let fft = TempiFFT(withSize: 2048, sampleRate: 44100.0)
        fft.windowType = TempiFFTWindowType.hamming
        var normalizer: Float = 0.0
        for i in 0...(2048-1) {
            normalizer += samples[i]*samples[i]
        }
        normalizer = sqrt(normalizer)
        var normalized_samples: Array<Float> = Array(repeating: 0.0, count: 2048)
        for i in 0...(2048-1) {
            normalized_samples[i] = samples[i] / normalizer
        }
        fft.fftForward(normalized_samples)
                
        let fileName = "fft" + String(file_count) + ".txt"
        file_count += 1

        var mags = fft.getMagnitudes()
        print(mags[0])
        var data_str = "["
        for i in 0...1023 {
            data_str += String(mags[i])
            if i < 1023 {
                data_str += ","
            }
        }
        data_str += "]"

        self.save(text: data_str,
                  toDirectory: self.documentDirectory(),
                  withFileName: fileName)
    }
    
    
    override func didReceiveMemoryWarning() {
        NSLog("*** Memory!")
        super.didReceiveMemoryWarning()
    }
    
    private func save(text: String,
                      toDirectory directory: String,
                      withFileName fileName: String) {
        guard let filePath = self.append(toPath: directory,
                                         withPathComponent: fileName) else {
            return
        }
        
        do {
            try text.write(toFile: filePath,
                           atomically: true,
                           encoding: .utf8)
        } catch {
            print("Error", error)
            return
        }
        
        print("Save successful")
    }
    
    private func documentDirectory() -> String {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                                    .userDomainMask,
                                                                    true)
        return documentDirectory[0]
    }
    
    private func append(toPath path: String,
                        withPathComponent pathComponent: String) -> String? {
        if var pathURL = URL(string: path) {
            pathURL.appendPathComponent(pathComponent)
            
            return pathURL.absoluteString
        }
        
        return nil
    }
}


