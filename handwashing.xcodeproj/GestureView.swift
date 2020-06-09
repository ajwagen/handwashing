//
//  GestureView.swift
//  gesture_sensor
//
//  Created by Andrew Wagenmaker on 4/24/20.
//  Copyright © 2020 Andrew Wagenmaker. All rights reserved.
//

import Foundation
import UIKit

class GestureView: UIView {

    var fft: TempiFFT!
    var last_time: Int64 = 0
    var freqLabelStr = ""

    override func draw(_ rect: CGRect) {
        
        if fft == nil {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        
        let viewWidth = self.bounds.size.width
        let viewHeight = self.bounds.size.height
        
        context?.saveGState()
        
        let pointSize: CGFloat = 200.0
        let font = UIFont.systemFont(ofSize: pointSize, weight: .regular)
        
        let width = fft.lr_width()
        
        if width.l_width > 1 {
            self.freqLabelStr = "PULL"
            self.last_time = Int64(NSDate().timeIntervalSince1970 * 1000)
        } else if width.r_width > 1 {
            self.freqLabelStr = "PUSH"
            self.last_time = Int64(NSDate().timeIntervalSince1970 * 1000)
        } else {
            var current_time = Int64(NSDate().timeIntervalSince1970 * 1000)
            if current_time - self.last_time > 250 {
                self.freqLabelStr = ""
            }
        }
        
        var attrStr = NSMutableAttributedString(string: self.freqLabelStr)
        attrStr.addAttribute(.font, value: font, range: NSMakeRange(0, self.freqLabelStr.count))
        attrStr.addAttribute(.foregroundColor, value: UIColor.red, range: NSMakeRange(0, self.freqLabelStr.count))
        
        var x: CGFloat = viewWidth / 2.0 - attrStr.size().width / 2.0
        var y: CGFloat = viewHeight / 2.0 - attrStr.size().height / 2.0
        attrStr.draw(at: CGPoint(x: x, y:y))
        context?.restoreGState()
    }
}
