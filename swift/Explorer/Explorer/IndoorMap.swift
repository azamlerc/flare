//
//  IndoorMap.swift
//  Explorer
//
//  Created by Andrew Zamler-Carhart on 8/17/15.
//  Copyright (c) 2015 Andrew Zamler-Carhart. All rights reserved.
//

import Cocoa
import Flare
import CoreGraphics

@IBDesignable
class IndoorMap: NSView {
    
    var environment: Environment?
    var zones = [Zone]()
    var things = [Thing]()
    var nearbyThing: Thing? {
        didSet {
            // self.needsDisplay = true
        }
    }
    var environmentFlipped = false
    var selectedFlare: Flare?
    var labels = [String:NSTextField]()
    
    var viewHeight: CGFloat = 768.0
    var gridCenter = CGPoint(x: 0,y: 0)
    var insetCenter = CGPoint(x: 0,y: 0)
    var gridOrigin = CGPoint(x: 0,y: 0)
    var scale: CGFloat = 1.0
    
    let white = NSColor(red:1, green:1, blue:1, alpha:0.5)
    let lightGray = NSColor(red:0, green:0, blue:0, alpha:0.1)
    let pink = NSColor(red:1, green:0, blue:0, alpha:0.5)
    let blue = NSColor(red:0, green:0, blue:1, alpha:0.5)
    let lightBlue = NSColor(red:0, green:0, blue:1, alpha:0.15)
    let halo = NSColor(red:48.0/256.0, green:131.0/256.0, blue:251.0/256.0, alpha:0.5)
    let selectedColor = NSColor(red:48.0/256.0, green:131.0/256.0, blue:251.0/256.0, alpha:0.5)
    
    func loadEnvironment(value: Environment) {
        if value != environment {
            for (_,label) in labels {
                label.removeFromSuperview()
            }
            labels.removeAll(keepingCapacity: true)
            
            self.environment = value
            
            if environment != nil {
                if self.window != nil {
                    self.window!.title = environment!.name
                }

                updateFlipped()
                updateScale()
                self.zones = environment!.zones
                self.things = environment!.things()
                self.needsDisplay = true
            }
        }
    }
    
    override var isFlipped:Bool {
        get {
            return environmentFlipped
        }
    }

    func updateFlipped() {
        if environment != nil {
            if let flipped = environment!.data["flipped"] as? Int {
                self.environmentFlipped = flipped != 0
            } else {
                self.environmentFlipped = false
            }
        }
    }
    
    func dataChanged() {
        updateFlipped()
        self.needsDisplay = true
    }
    
    func labelForFlare(flare: Flare) -> NSTextField {
        var label = labels[flare.id]
        if (label == nil) {
            label = NSTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
            label!.font = NSFont.systemFont(ofSize: 13)
            label!.textColor = NSColor.black
            label!.stringValue = flare.name
            label!.isEditable = false
            label!.drawsBackground = false
            label!.isBezeled = false
            label!.alignment = .center
            self.addSubview(label!)
            labels[flare.id] = label!
        }
        return label!
    }

    func updateScale() {
        let inset = self.frame.insetBy(dx: 20, dy: 20)
        let grid = environment!.perimeter
        let xScale = inset.size.width / grid.size.width
        let yScale = inset.size.height / grid.size.height
        scale = (xScale < yScale) ? xScale : yScale
    }
    
    override func draw(_ rect: CGRect) {
        if (environment != nil) {
            let inset = NSRect(origin: .zero, size: self.frame.size).insetBy(dx: 20, dy: 20)
            let grid = environment!.perimeter.toRect()

            updateScale()
            insetCenter = inset.center()
            gridCenter = grid.center()
            
            fillRect(rect: grid, color: white, inset: 0)

            for zone in zones {
                fillRect(rect: zone.perimeter.toRect(), color: white, inset: 2)
                
                let label = labelForFlare(flare: zone)
                label.frame.origin = convertPoint(gridPoint: zone.perimeter.center().toPoint()) - CGSize(width: 100, height: 10)
            }
            
            for thing in things {
                let color = IndoorMap.colorForThing(thing: thing)

                if thing == selectedFlare {
                    fillCircle(center: thing.position.toPoint(), radius: 15, color: selectedColor)
                }
                if thing == nearbyThing {
                    fillCircle(center: thing.position.toPoint(), radius: 15, color: halo)
                }
                fillCircle(center: thing.position.toPoint(), radius: 10, color: color)
                
                let label = labelForFlare(flare: thing)
                label.frame.origin = convertPoint(gridPoint: thing.position.toPoint()) - CGSize(width: 100, height: environmentFlipped ? -12 : 33)
            }

            for device in environment!.devices {
                if device == selectedFlare {
                    fillCircle(center: device.position.toPoint(), radius: 15, color: selectedColor)
                }
                fillCircle(center: device.position.toPoint(), radius: 10, color: blue)

                let label = labelForFlare(flare: device)
                label.frame.origin = convertPoint(gridPoint: device.position.toPoint()) - CGSize(width: 100, height: environmentFlipped ? -12 : 33)
            }
        }
    }
    
    static func colorForThing(thing: Thing) -> NSColor {
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
    
    static func getColor(name: String, brightness: Double) -> NSColor {
        if name == "clear" { return NSColor.clear }
        if name == "white" { return NSColor(hue: 0, saturation: 0, brightness: 0.95, alpha: 1.0) }

        if let hex = LightManager.htmlColorNames[name] {
            return colorWithHex(rgbValue: hex)
        }
        
        return NSColor.red
    }
    
    static func colorWithHex(rgbValue: Int) -> NSColor {
        return NSColor(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
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
    
    func fillRect(rect: CGRect, color: NSColor, inset: CGFloat) {
        let converted = convertRect(gridRect: rect)
        let inset = converted.insetBy(dx: inset, dy: inset)
        if inset.size.width > 0 && inset.size.height > 0 {
            let path = NSBezierPath(rect: inset)
            color.setFill()
            path.fill()
        }
    }
    
    func fillCircle(center: CGPoint, radius: CGFloat, color: NSColor) {
        let newCenter = convertPoint(gridPoint: center)
        let rect = CGRect(x: newCenter.x - radius, y: newCenter.y - radius, width: radius * 2, height: radius * 2)
        if rect.origin.x < 10000000 && rect.origin.y < 10000000 {
            let path = NSBezierPath(ovalIn: rect)
            color.setFill()
            path.fill()
        }
    }
    
    func flipPoint(point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: self.bounds.height - point.y)
    }
    
    func convertPoint(gridPoint: CGPoint) -> CGPoint {
        return CGPoint(x: round(insetCenter.x - (gridCenter.x - gridPoint.x) * scale),
            y: round(insetCenter.y - (gridCenter.y - gridPoint.y) * scale))
    }
    
    func convertSize(gridSize: CGSize) -> CGSize {
        return CGSize(width: round(gridSize.width * scale), height: round(gridSize.height * scale))
    }
    
    func convertRect(gridRect: CGRect) -> CGRect {
        return CGRect(origin: convertPoint(gridPoint: gridRect.origin), size: convertSize(gridSize: gridRect.size))
    }
}
