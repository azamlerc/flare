//
//  ColorButton.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 12/11/15.
//  Copyright © 2015 Cisco. All rights reserved.
//

import UIKit

class ColorButton: UIButton {
    var colorName = "red"
    
    let selectedColor = UIColor(red:48.0/256.0, green:131.0/256.0, blue:251.0/256.0, alpha:0.5)
    
    override func draw(_ rect: CGRect) {
        if isSelected {
            let ringRect = self.bounds.insetBy(dx: 5, dy: 5)
            let path = UIBezierPath(ovalIn: ringRect)
            selectedColor.setFill()
            path.fill()
        }

        let color = IndoorMap.getColor(name: colorName, brightness: 0.5)
        let colorRect = self.bounds.insetBy(dx: 10, dy: 10)
        let path = UIBezierPath(ovalIn: colorRect)
        color.setFill()
        path.fill()
    }
}
