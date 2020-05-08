//
//  IndoorMap.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 3/26/15.
//  Copyright (c) 2015 Cisco. All rights reserved.
//

import UIKit
import Flare
import CoreGraphics

class IndoorMap: UIView, FlareController {
    
    var appDelegate = UIApplication.shared.delegate as! AppDelegate
    var currentEnvironment: Environment? {
        didSet(value) {
            if value != currentEnvironment {
                for (_,label) in labels {
                    label.removeFromSuperview()
                }
                labels.removeAll(keepingCapacity: true)
                
                if currentEnvironment != nil {
                    updateFlipped()
                    updateScale()
                    self.zones = currentEnvironment!.zones
                    self.things = currentEnvironment!.things()
                    setNeedsDisplay()
                }
            }
        }
    }
    var flipped = false
    var currentZone: Zone? { didSet(value) { /* highlight? */ }}
    var zones = [Zone]()
    var things = [Thing]()
    var device: Device? { didSet { setNeedsDisplay() }}
    var nearbyThing: Thing? { didSet { setNeedsDisplay() }}
    
    var labels = [String:UILabel]()
    
    var viewHeight: CGFloat = 768.0
    var gridCenter = CGPoint(x: 0,y: 0)
    var insetCenter = CGPoint(x: 0,y: 0)
    var gridOrigin = CGPoint(x: 0,y: 0)
    var scale: CGFloat = 1.0
    
    let lightGray = UIColor(red:0, green:0, blue:0, alpha:0.1)
    let pink = UIColor(red:1, green:0, blue:0, alpha:0.5)
    let blue = UIColor(red:0.4, green:0.4, blue:1, alpha:1.0)
    let lightBlue = UIColor(red:0, green:0, blue:1, alpha:0.15)
    let halo = UIColor(red:1, green:1, blue:0, alpha:0.5)
    let selectedColor = UIColor(red:48.0/256.0, green:131.0/256.0, blue:251.0/256.0, alpha:0.5)
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector:#selector(IndoorMap.orientationDidChange(note:)), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
    @objc func orientationDidChange(note: NSNotification) {
        dataChanged()
    }

    func dataChanged() {
        self.setNeedsDisplay()
    }
    
    func animate() {
        self.setNeedsDisplay()
    }
    
    // sender.identifier can contain several words
    // the first word is the action
    @IBAction func performAction(_ sender: UIButton) {
        let identifiers = sender.accessibilityIdentifier!.components(separatedBy: " ")
        let action = identifiers.first!
        
        if device != nil { appDelegate.flareManager.performAction(flare: device!, action: action, sender: nil) }
    }

    func labelForFlare(flare: Flare) -> UILabel {
        var label = labels[flare.id]
        if (label == nil) {
            label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
            label!.textAlignment = NSTextAlignment.center
            label!.textColor = UIColor.gray
            label!.text = flare.name
            self.addSubview(label!)
            labels[flare.id] = label!
        }
        return label!
    }
    
    func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        NSLog("Will rotate")

        coordinator.animate(alongsideTransition: nil, completion: { context in
            NSLog("Completion")
            
            self.dataChanged()
        })
    }
            
    func updateScale() {
        let inset = self.frame.insetBy(dx: 40, dy: 40)
        let grid = currentEnvironment!.perimeter
        let xScale = inset.size.width / grid.size.width
        let yScale = inset.size.height / grid.size.height
        scale = (xScale < yScale) ? xScale : yScale
    }

    func updateFlipped() {
        if currentEnvironment != nil {
            if let flipped = currentEnvironment!.data["flipped"] as? Int {
                self.flipped = flipped != 0
            } else {
                self.flipped = false
            }
        }
        NSLog("Flipped: \(self.flipped ? "yes" : "no")")
    }

    override func draw(_ rect: CGRect) {
        if (currentEnvironment != nil) {
            let context = UIGraphicsGetCurrentContext()
            context!.scaleBy(x: 1, y: -1);
            context!.translateBy(x: 0, y: -self.bounds.size.height);
            
            let inset = self.frame.insetBy(dx: 40, dy: 40)
            let grid = currentEnvironment!.perimeter.toRect()
            
            updateScale()
            insetCenter = inset.center()
            gridCenter = grid.center()
            
            fillRect(rect: grid, color: lightGray, inset: 0)
            
            for zone in zones {
                fillRect(rect: zone.perimeter.toRect(), color: lightGray, inset: 2)

                let label = labelForFlare(flare: zone)
                label.center = flipPoint(point: convertPoint(gridPoint: zone.perimeter.toRect().center()))
            }

            if device != nil && nearbyThing != nil {
                let line = UIBezierPath()
                line.move(to: convertPoint(gridPoint: device!.position.toPoint()))
                line.addLine(to: convertPoint(gridPoint: nearbyThing!.position.toPoint()))
                line.lineWidth = 3
                selectedColor.setStroke()
                line.stroke()
            }

            for thing in things {
                let color = IndoorMap.colorForThing(thing: thing)
                
                if thing == nearbyThing { fillCircle(center: thing.position.toPoint(), radius: 15, color: selectedColor) }
                fillCircle(center: thing.position.toPoint(), radius: 10, color: color)
                
                let label = labelForFlare(flare: thing)
                label.center = flipPoint(point: convertPoint(gridPoint: thing.position.toPoint()) + CGSize(width: 2, height: -22))
            }
            
            if device != nil && !device!.position.x.isNaN && !device!.position.y.isNaN {
                if nearbyThing != nil { fillCircle(center: device!.position.toPoint(), radius: 15, color: selectedColor) }
                fillCircle(center: device!.position.toPoint(), radius: 10, color: blue)
                
                let label = labelForFlare(flare: device!)
                label.center = flipPoint(point: convertPoint(gridPoint: device!.position.toPoint()) + CGSize(width: 2, height: -22))
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let viewPoint = touch.location(in: self)
            let gridPoint = undoConvertPoint(viewPoint: flipPoint(point: viewPoint))
            if let thing = thingNearPoint(point: gridPoint) {
                appDelegate.nearbyThing = thing
            }
        }
    }
    
    func thingNearPoint(point: CGPoint) -> Thing? {
        for thing in things {
            if thing.position.toPoint() - point < 1.0 {
                return thing
            }
        }
        return nil
    }
    
    static func colorForThing(thing: Thing) -> UIColor {
        var colorName = "red"
        var brightness = 0.5
        
        if let value = thing.data["color"] as? String {
            colorName = value
        }
        
        if let value = thing.data["brightness"] as? Double {
            brightness = value
        }
        
        return getColor(name: colorName, brightness: brightness)
    }

    static func getColor(name: String, brightness: Double) -> UIColor {
        if name == "clear" { return UIColor.clear }
        if name == "white" { return UIColor(hue: 0, saturation: 0, brightness: 0.95, alpha: 1.0) }
        
        if let hex = LightManager.htmlColorNames[name] {
            return colorWithHex(rgbValue: hex)
        }
        
        return UIColor.red
    }
    
    static func colorWithHex(rgbValue: Int) -> UIColor {
        return UIColor(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                     green: CGFloat((rgbValue & 0x00FF00) >>  8) / 255.0,
                      blue: CGFloat((rgbValue & 0x0000FF) >>  0) / 255.0,
                     alpha: 1.0)
    }
    
    static func hue(name: String) -> CGFloat {
        if name == "red" { return 0 }
        if name == "orange" { return 0.08333333 }
        if name == "yellow" { return 0.16666666 }
        if name == "green" { return 0.3333333 }
        if name == "blue" { return 0.66666666 }
        if name == "purple" { return 0.7777777 }
        return 0
    }
    
    func fillRect(rect: CGRect, color: UIColor, inset: CGFloat) {
        let path = UIBezierPath(rect: convertRect(gridRect: rect).insetBy(dx: inset, dy: inset))
        color.setFill()
        path.fill()
    }
    
    func fillCircle(center: CGPoint, radius: CGFloat, color: UIColor) {
        let newCenter = convertPoint(gridPoint: center)
        let rect = CGRect(x: newCenter.x - radius, y: newCenter.y - radius, width: radius * 2, height: radius * 2)
        let path = UIBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()
    }
    
    func flipPoint(point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: self.bounds.height - point.y)
    }
    
    func convertPoint(gridPoint: CGPoint) -> CGPoint {
        return CGPoint(x: round(insetCenter.x - (gridCenter.x - gridPoint.x) * scale),
            y: round(insetCenter.y - (gridCenter.y - gridPoint.y) * scale * (flipped ? -1 : 1)))
    }
    
    func convertSize(gridSize: CGSize) -> CGSize {
        return CGSize(width: round(gridSize.width * scale),
            height: round(gridSize.height * scale * (flipped ? -1 : 1)))
    }
    
    func convertRect(gridRect: CGRect) -> CGRect {
        return CGRect(origin: convertPoint(gridPoint: gridRect.origin), size: convertSize(gridSize: gridRect.size))
    }
    
    func undoConvertPoint(viewPoint: CGPoint) -> CGPoint {
        return CGPoint(x: gridCenter.x - (insetCenter.x - viewPoint.x) / scale,
            y: gridCenter.y - (insetCenter.y - viewPoint.y) / scale * (flipped ? -1 : 1))
    }
}
