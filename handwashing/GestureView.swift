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
    
    var freqLabelStr = ""

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        
        let viewWidth = self.bounds.size.width
        let viewHeight = self.bounds.size.height
        
        context?.saveGState()
        
        //let pointSize: CGFloat = 200.0
        let pointSize: CGFloat = 50.0
        let font = UIFont.systemFont(ofSize: pointSize, weight: .regular)
        
        var attrStr = NSMutableAttributedString(string: self.freqLabelStr)
        attrStr.addAttribute(.font, value: font, range: NSMakeRange(0, self.freqLabelStr.count))
        attrStr.addAttribute(.foregroundColor, value: UIColor.red, range: NSMakeRange(0, self.freqLabelStr.count))
        
        var x: CGFloat = viewWidth / 2.0 - attrStr.size().width / 2.0
        var y: CGFloat = viewHeight / 2.0 - attrStr.size().height / 2.0
        attrStr.draw(at: CGPoint(x: x, y:y))
        context?.restoreGState()
    }
}
