//
//  ViewController.swift
//  gesture_sensor
//
//  Created by Andrew Wagenmaker on 4/22/20.
//  Copyright © 2020 Andrew Wagenmaker. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, UIApplicationDelegate, AVAudioPlayerDelegate {
    
    @IBOutlet weak var gestureView: GestureView!
  
    var audioInput: TempiAudioInput!
    var audioPlayer = AVAudioPlayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let audioInputCallback: TempiAudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            self.gotSomeAudio(timeStamp: Double(timeStamp), numberOfFrames: Int(numberOfFrames), samples: samples)
        }
        
        let test_sound = Bundle.main.path(forResource: "tone_18khz", ofType: "wav")
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: test_sound!))
            audioPlayer.delegate = self
        
        } catch {
            
        }
        
        audioPlayer.play()
        
        audioInput = TempiAudioInput(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        audioInput.startRecording()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer.play()
    }

    func gotSomeAudio(timeStamp: Double, numberOfFrames: Int, samples: [Float]) {
        let fft = TempiFFT(withSize: 512, sampleRate: 44100.0)
        fft.windowType = TempiFFTWindowType.hamming
        fft.fftForward(samples)

        tempi_dispatch_main { () -> () in
            self.gestureView.fft = fft
            self.gestureView.setNeedsDisplay()
        }
    }
    
    override func didReceiveMemoryWarning() {
        NSLog("*** Memory!")
        super.didReceiveMemoryWarning()
    }
}


