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

public struct Point3D {
    public var x: CGFloat
    public var y: CGFloat
    public var z: CGFloat
    
    public init(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public init(x: Double, y: Double, z: Double) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
        self.z = CGFloat(z)
    }
}

let Point3DZero = Point3D(x: CGFloat(0), y: CGFloat(0), z: CGFloat(0))

public struct Size3D {
    public var width: CGFloat
    public var height: CGFloat
    public var depth: CGFloat
    
    public init(width: CGFloat, height: CGFloat, depth: CGFloat) {
        self.width = width
        self.height = height
        self.depth = depth
    }
}

public struct Cube3D {
    public var origin: Point3D
    public var size: Size3D
    
    public init(origin: Point3D, size: Size3D) {
        self.origin = origin
        self.size = size
    }
}

// compare JSONDictionary objects
public func ==(lhs: JSONDictionary, rhs: JSONDictionary) -> Bool {
    return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

public func ==(a: Point3D, b: Point3D) -> Bool {
    return a.x == b.x && a.y == b.y && a.z == b.z
}

public func ==(a: Size3D, b: Size3D) -> Bool {
    return a.width == b.width && a.height == b.height && a.depth == b.depth
}

public func ==(a: Cube3D, b: Cube3D) -> Bool {
    return a.origin == b.origin && a.size == b.size
}

// a point translated by the given size
public func +(point: CGPoint, size: CGSize) -> CGPoint {
    let x = point.x + size.width
    let y = point.y + size.height
    return CGPoint(x:x, y:y)
}

public func +(point: Point3D, size: Size3D) -> Point3D {
    let x = point.x + size.width
    let y = point.y + size.height
    let z = point.z + size.depth
    return Point3D(x:x, y:y, z:z)
}

// a point negatively translated by the given size
public func -(point: CGPoint, size: CGSize) -> CGPoint {
    let x = point.x - size.width
    let y = point.y - size.height
    return CGPoint(x:x , y:y)
}

public func -(point: Point3D, size: Size3D) -> Point3D {
    let x = point.x - size.width
    let y = point.y - size.height
    let z = point.z - size.depth
    return Point3D(x:x, y:y, z:z)
}

// the distance between two points (diagonal)
public func -(point1: CGPoint, point2: CGPoint) -> Double {
    let dx = point1.x - point2.x
    let dy = point1.y - point2.y
    return Double(sqrt(dx * dx + dy * dy))
}

public func -(point1: Point3D, point2: Point3D) -> Double {
    let dx = point1.x - point2.x
    let dy = point1.y - point2.y
    let dz = point1.z - point2.z
    return Double(sqrt(dx * dx + dy * dy + dz * dz))
}

// the difference between two sizes
public func -(size1: CGSize, size2: CGSize) -> CGSize {
    let width = size1.width - size2.width
    let height = size1.height - size2.height
    return CGSize(width:width, height:height)
}

public func -(size1: Size3D, size2: Size3D) -> Size3D {
    let width = size1.width - size2.width
    let height = size1.height - size2.height
    let depth = size1.depth - size2.depth
    return Size3D(width:width, height:height, depth:depth)
}

// a point scaled by the given ratio
public func *(point: CGPoint, ratio: CGFloat) -> CGPoint {
    let x = point.x * ratio
    let y = point.y * ratio
    return CGPoint(x:x, y:y)
}

public func *(point: Point3D, ratio: CGFloat) -> Point3D {
    let x = point.x * ratio
    let y = point.y * ratio
    let z = point.z * ratio
    return Point3D(x:x, y:y, z:z)
}

// a size scaled by the given ratio
public func *(size: CGSize, ratio: CGFloat) -> CGSize {
    let width = size.width * ratio
    let height = size.height * ratio
    return CGSize(width:width, height:height)
}

public func *(size: Size3D, ratio: CGFloat) -> Size3D {
    let width = size.width * ratio
    let height = size.height * ratio
    let depth = size.depth * ratio
    return Size3D(width:width, height:height, depth:depth)
}

// a rect scaled by the given ratio
public func *(rect: CGRect, ratio: CGFloat) -> CGRect {
    let origin = rect.origin * ratio
    let size = rect.size * ratio
    return CGRect(origin:origin, size:size)
}

public func *(rect: Cube3D, ratio: CGFloat) -> Cube3D {
    let origin = rect.origin * ratio
    let size = rect.size * ratio
    return Cube3D(origin:origin, size:size)
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

public func randomSize3D(min: Int, max: Int) -> Size3D {
    let width = randomInt(min: min, max: max)
    let height = randomInt(min: min, max: max)
    let depth = randomInt(min: min, max: max)
    return Size3D(width:CGFloat(width), height:CGFloat(height), depth:CGFloat(depth))
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

public extension Cube3D {
    
    // returns the point at the center of the cube
    func center() -> Point3D {
        return Point3D(x: self.origin.x + self.size.width / 2.0,
            y: self.origin.y + self.size.height / 2.0,
            z: self.origin.z + self.size.depth / 2.0)
    }
    
    func contains(point: Point3D) -> Bool {
        return self.origin.x <= point.x && point.x <= self.origin.x + self.size.width &&
            self.origin.y <= point.y && point.y <= self.origin.y + self.size.height &&
            self.origin.z <= point.z && point.z <= self.origin.z + self.size.depth
    }
    
    func toRect() -> CGRect {
        return CGRect(origin: self.origin.toPoint(), size: self.size.toSize())
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

public extension Size3D {
    
    // returns the diagonal length
    func length() -> Double {
        let x2 = Double(self.width * self.width)
        let y2 = Double(self.height * self.height)
        let z2 = Double(self.depth * self.depth)
        return sqrt(x2 + y2 + z2)
    }
    
    func toSize() -> CGSize {
        return CGSize(width: self.width, height: self.height)
    }
    
    func toJSON() -> JSONDictionary {
        return ["width": self.width, "height": self.height, "depth": self.depth]
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

public extension Point3D {
    
    // rounds the point's x and y values to the given precision
    func roundTo(precision: Double) -> Point3D {
        return Point3D(x: CGFloat(self.x.roundTo(precision: precision)),
                       y: CGFloat(self.y.roundTo(precision: precision)),
                       z: CGFloat(self.z.roundTo(precision: precision)))
    }
    
    func toPoint() -> CGPoint {
        return CGPoint(x: self.x, y: self.y)
    }
    
    func toJSON() -> JSONDictionary {
        return ["x": self.x as AnyObject, "y": self.y as AnyObject, "z": self.z]
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
        
        return (newWords as NSArray).componentsJoined(by: " ")
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

