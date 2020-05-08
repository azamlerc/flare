//
//  Extensions.swift
//  Facets Dashboard
//
//  Created by Andrew Zamler-Carhart on 16/09/2014.
//  Copyright (c) 2014 Cisco. All rights reserved.
//

import Foundation
import CoreGraphics

public typealias JSONDictionary = [String:Any]
public typealias JSONArray = [JSONDictionary]

// compare JSONDictionary objects
public func ==(lhs: JSONDictionary, rhs: JSONDictionary) -> Bool {
    return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

// a point translated by the given size
public func +(point: CGPoint, size: CGSize) -> CGPoint {
    let x = point.x + size.width
    let y = point.y + size.height
    return CGPoint(x:x, y:y)
}

// a point negatively translated by the given size
public func -(point: CGPoint, size: CGSize) -> CGPoint {
    let x = point.x - size.width
    let y = point.y - size.height
    return CGPoint(x:x , y:y)
}

// the distance between two points (width and height)
/*
func -(point1: CGPoint, point2: CGPoint) -> CGSize {
    let width = point1.x - point2.x
    let height = point1.y - point2.y
    return CGSize(width:width, height:height)
}
*/

// the distance between two points (diagonal)
public func -(point1: CGPoint, point2: CGPoint) -> Double {
    let dx = point1.x - point2.x
    let dy = point1.y - point2.y
    return Double(sqrt(dx * dx + dy * dy))
}

// the difference between two sizes
public func -(size1: CGSize, size2: CGSize) -> CGSize {
    let width = size1.width - size2.width
    let height = size1.height - size2.height
    return CGSize(width:width, height:height)
}

// a point scaled by the given ratio
public func *(point: CGPoint, ratio: CGFloat) -> CGPoint {
    let x = point.x * ratio
    let y = point.y * ratio
    return CGPoint(x:x, y:y)
}

// a size scaled by the given ratio
public func *(size: CGSize, ratio: CGFloat) -> CGSize {
    let width = size.width * ratio
    let height = size.height * ratio
    return CGSize(width:width, height:height)
}

// a rect scaled by the given ratio
public func *(rect: CGRect, ratio: CGFloat) -> CGRect {
    let origin = rect.origin * ratio
    let size = rect.size * ratio
    return CGRect(origin:origin, size:size)
}

// returns a random Int between 0 and limit - 1
public func randomInt(limit:Int) -> Int {
    return limit > 0 ? Int(arc4random_uniform(UInt32(limit))) : 0
}

// returns a random Int between min and max inclusive
public func randomInt(min: Int, max: Int) -> Int {
    return min + randomInt(limit: max - min + 1)
}

// a random size with each dimension between min and max
public func randomSize(min: Int, max: Int) -> CGSize {
    let width = randomInt(min: min, max: max)
    let height = randomInt(min: min, max: max)
    return CGSize(width:width, height:height)
}

public extension Array {
    
    // returns a random object from the array
    func randomObject() -> Element  {
        return self[randomInt(limit: self.count)]
    }

    // removes an object from the array by value
    mutating func removeObject<U: Equatable>(object: U) {
        var index: Int?
        for (idx, objectToCompare) in self.enumerated() {
            if let to = objectToCompare as? U {
                if object == to {
                    index = idx
                }
            }
        }
        
        if (index != nil) {
            self.remove(at: index!)
        }
    }
}

public extension Double {
    
    // returns the number rounded to the given precision
    // for example, 17.37.roundTo(0.5) returns 17.5
    func roundTo(precision: Double) -> Double {
        return (self + precision / 2.0).roundDown(precision: precision)
    }
    
    // returns the number rounded down to the given precision
    // for example, 17.37.roundTo(0.5) returns 17.0
    func roundDown(precision: Double) -> Double {
        return Double(Int(self / precision)) * precision
    }
}

public extension CGRect {
    
    // returns the point at the center of the rectangle
    func center() -> CGPoint {
        return CGPoint(x: (self.minX + self.maxX) / 2.0,
            y: (self.minY + self.maxY) / 2.0)
    }

    func toJSON() -> JSONDictionary {
        return ["origin": self.origin.toJSON(), "size": self.size.toJSON()]
    }
}

public extension CGSize {
    
    // returns the diagonal length
    func length() -> Double {
        let x2 = Double(self.width * self.width)
        let y2 = Double(self.height * self.height)
        return sqrt(x2 + y2)
    }
    
    func toJSON() -> JSONDictionary {
        return ["width": self.width, "height": self.height]
    }
}

public extension CGPoint {
    
    // rounds the point's x and y values to the given precision
    func roundTo(precision: Double) -> CGPoint {
        return CGPoint(x: self.x.roundTo(precision: precision), y: self.y.roundTo(precision: precision))
    }
    
    func toJSON() -> JSONDictionary {
        return ["x": self.x, "y": self.y]
    }
}

public extension CGFloat {
    
    // adds the same rounding behavior to CGFloat
    func roundTo(precision: Double) -> Double {
        return Double(self).roundTo(precision: precision)
    }
}

public func radiansToDegrees(radians: Double) -> Double {
    return radians * 180.0 / Double.pi
}

public func degreesToRadians(degrees: Double) -> Double {
    return degrees * Double.pi / 180.0
}

public extension Int {
    
    // calls the closure a number of times
    // e.g. 5.times { // do stuff }
    func times(closure: () -> ()) {
        if self > 0 {
            for _ in 1...self {
                closure()
            }
        }
    }
}

// calls the closure in the main queue
public func queue(closure:@escaping ()->()) {
    DispatchQueue.main.async(execute: closure)
}

// calls the closure in the background
public func background(closure:@escaping ()->()) {
    DispatchQueue.global(qos: .userInitiated).async(execute: closure)
}

// calls the closure after the delay
// e.g. delay(5.0) { // do stuff }
public func delay(duration:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: closure)
}

// calls the closure repeatedly over a period of time
// duration controls the total length of time
// steps controls the number of intermediate steps
// the counter variable i will be passed to the closure
public func delayLoop(duration:Double, steps:Int, closure: @escaping (_ i:Int)->()) {
    for i in 1...steps {
        delay(duration: Double(i) * (duration / Double(steps))) {
            closure(i)
        }
    }
}

public extension String {
    
    func titlecaseString() -> String {
        let words = self.components(separatedBy: " ")
        var newWords = [String]()
        
        for word in words {
            let firstLetter = (word as NSString).substring(to: 1)
            let restOfWord = (word as NSString).substring(from: 1)
            newWords.append("\(firstLetter.uppercased())\(restOfWord.lowercased())")
        }
        
        return newWords.joined(separator: " ")
    }
}

public extension NSMutableString {
    
    // replaces all occurrences of one string with another
    func replace(target: String, with: String) {
        self.replaceOccurrences(of: target, with: with, options: [], range: NSRange(location: 0, length: self.length))
    }
}

public extension NSData {

    // converts NSData to an NSDictionary
    func toJSONDictionary() -> JSONDictionary? {
        let json: JSONDictionary?
        do {
            json = try JSONSerialization.jsonObject(with: self as Data, options: []) as? JSONDictionary
        } catch _ {
            json = nil
        }
        return json
    }
}

public extension Dictionary {

    // converts a JSONDictionary to NSData
    func toData() -> NSData? {
        let data: NSData?
        do {
            data = try JSONSerialization.data(withJSONObject: self, options:[]) as NSData
        } catch _ {
            data = nil
        }
        return data
    }
    
    func toJSONString() -> String? {
        if let data = self.toData() {
            return NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue) as String?
        } else {
            return nil
        }
    }
}

// objects that can be initialized with no arguments
// necessary for getValue() to instantiate a new object of arbitrary type
// most classes can implement this protocol with no additional methods
protocol JSONValue {
    init()
    init(string: String)
}

// adds Initible conformace to basic types so they can be used by getValue()
extension String: JSONValue {
    init(string: String) {
        self.init(string)
    }
}

extension Int: JSONValue {
    init(string: String) {
        self.init((string as NSString).integerValue)
    }
}
extension Double: JSONValue {
    init(string: String) {
        self.init((string as NSString).doubleValue)
    }
}
extension Array: JSONValue {
    init(string: String) {
        self.init()
    }
}

extension Dictionary {
    
    // getValue will try to get an object with the given key from the dictionary
    // returns an object of the given type rather than AnyObject?
    // if the object is not found, returns a new object of the type
    func getValue<T: JSONValue>(key: String, type: T.Type) -> T {
        if let value = self[key as! Key] {
            if let typedValue = value as? T {
                return typedValue
            } else if let stringValue = value as? String {
                // NSLog("Got string: \(value)")
                return T(string:stringValue)
            }
        }
        
        return T()
    }
    
    func getString(key: String) -> String {
        return getValue(key: key, type: String.self)
    }
    
    func getInt(key: String) -> Int {
        return getValue(key: key, type: Int.self)
    }
    
    func getDouble(key: String) -> Double {
        return getValue(key: key, type: Double.self)
    }
    
    func getArray(key: String) -> JSONArray {
        return getValue(key: key, type: JSONArray.self)
    }
    
    func getStringArray(key: String) -> [String] {
        return getValue(key: key, type: [String].self)
    }
    
    func getDate(key: String) -> NSDate {
        let dateString = getString(key: key)
        let mongoFormatter = DateFormatter()
        mongoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = mongoFormatter.date(from: dateString) {
            return date as NSDate
        } else {
            return NSDate()
        }
    }
    
    func getDictionary(key: String) -> JSONDictionary {
        if let value = self[key as! Key] {
            return value as! JSONDictionary
        } else {
            return [:]
        }
    }
}

