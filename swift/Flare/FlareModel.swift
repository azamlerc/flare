//
//  Environment.swift
//  Flare Test
//
//  Created by Andrew Zamler-Carhart on 3/23/15.
//  Copyright (c) 2015 Andrew Zamler-Carhart. All rights reserved.
//

import CoreGraphics
import Foundation

public class Flare: NSObject {
    public var id: String
    public var name: String
    public var comment: String
    public var data: JSONDictionary
    public var actions: [String]
    public var created: NSDate
    public var modified: NSDate
    public var distance: Double? // the distance from the current position

    public init(json: JSONDictionary) {
        self.id = json.getString(key: "_id")
        self.name = json.getString(key: "name")
        self.comment = json.getString(key: "description") // description is a property of NSObject
        self.data = json.getDictionary(key: "data")
        self.actions = json.getStringArray(key: "actions")
        self.created = json.getDate(key: "created")
        self.modified = json.getDate(key: "modified")
    }

    public var flareClass: String {
        let className = NSStringFromClass(type(of: self)) as NSString
        return className.components(separatedBy: ".").last!
    }

    override public var description: String {
        return "\(self.flareClass) \(self.id) - \(self.name)"
    }

    public func setDistanceFrom(currentPosition: Point3D) {
        // override to calculate the distance
    }

    public var flareInfo: JSONDictionary {
        var info = JSONDictionary()
        info[self.flareClass.lowercased()] = self.id
        return info
    }

    public func parentId() -> String? {
        return nil
    }

    public func children() -> [Flare] {
        return Array()
    }

    public func childWithId(id: String) -> Flare? {
        for child in children() where child.id == id {
            return child
        }

        return nil
    }

    public func toJSON() -> JSONDictionary {
        var json = JSONDictionary()
        json["_id"] = self.id as AnyObject
        json["name"] = self.name as AnyObject
        json["description"] = self.comment as AnyObject
        json["data"] = self.data as AnyObject
        // json["created"] = self.created
        // json["modified"] = self.modified
        return json
    }
}

public protocol FlarePosition {
    var position: Point3D { get set }
}

public protocol FlarePerimeter {
    var perimeter: Cube3D { get set }
}

public class Environment: Flare, FlarePerimeter {
    public var geofence: Geofence
    public var perimeter: Cube3D
    public var angle: Double
    public var uuid: String?

    public var zones = [Zone]()
    public var devices = [Device]()

    public class func loadJson(json: JSONDictionary) -> [Environment] {
        var results = [Environment]()
        for child in json.getArray(key: "environments") {
            let environment = Environment(json: child)
            results.append(environment)
        }
        return results
    }

    override public init(json: JSONDictionary) {
        self.geofence = Geofence(json: json.getDictionary(key: "geofence"))
        self.perimeter = getCube3D(json: json.getDictionary(key: "perimeter"))
        self.angle = json.getDouble(key: "angle")

        for child: JSONDictionary in json.getArray(key: "zones") {
            let zone = Zone(json: child)
            zones.append(zone)
        }

        for child: JSONDictionary in json.getArray(key: "devices") {
            let device = Device(json: child)
            devices.append(device)
        }

        super.init(json: json)

        if let uuid = self.data["uuid"] as? String { self.uuid = uuid }
    }

    override public var description: String {
        return "\(super.description) - \(perimeter)"
    }

    override public func children() -> [Flare] {
        return self.zones
    }

    override public func toJSON() -> JSONDictionary {
        var json = super.toJSON()
        json["geofence"] = self.geofence.toJSON() as AnyObject
        json["perimeter"] = self.perimeter.toJSON() as AnyObject
        json["angle"] = self.angle as AnyObject
        if zones.count > 0 {json["zones"] = self.zones.map({$0.toJSON()}) as AnyObject}
        if devices.count > 0 {json["devices"] = self.devices.map({$0.toJSON()}) as AnyObject}
        return json
    }

    override public func setDistanceFrom(currentPosition latlong: Point3D) {
        self.distance = self.geofence.distanceFrom(latlong: latlong.toPoint())
    }

    public func here() -> Bool {
        return distance != nil && distance! * 1000 < self.geofence.radius
    }

    public func things() -> [Thing] {
        var results = [Thing]()
        for zone in zones {
            for thing in zone.things {
                results.append(thing)
            }
        }

        return results
    }

    public func beacons() -> [Int: Thing] {
        var results = [Int: Thing]()
        for zone in zones {
            if let major = zone.major {
                for thing in zone.things {
                    if let minor = thing.minor {
                        results[major * 10000 + minor] = thing
                        // NSLog("Beacon \(thing.name): \(zone.major!) \(thing.minor!)")
                    }
                }
            }
        }

        return results
    }
}

public class Zone: Flare, FlarePerimeter {
    public var environmentId: String

    public var perimeter: Cube3D
    public var center: Point3D
    public var major: Int?

    public var things = [Thing]()

    override public init(json: JSONDictionary) {
        self.environmentId = json.getString(key: "environment")

        self.perimeter = getCube3D(json: json.getDictionary(key: "perimeter"))
        self.center = self.perimeter.center()

        for child: JSONDictionary in json.getArray(key: "things") {
            let thing = Thing(json: child)
            things.append(thing)
        }

        super.init(json: json)

        if let major = self.data["major"] as? Int { self.major = major }
    }

    override public var description: String {
        return "\(super.description) - \(perimeter)"
    }

    override public func parentId() -> String? {
        return environmentId
    }

    override public func children() -> [Flare] {
        return self.things
    }

    override public func toJSON() -> JSONDictionary {
        var json = super.toJSON()
        json["perimeter"] = self.perimeter.toJSON() as AnyObject
        if things.count > 0 {json["things"] = self.things.map({$0.toJSON()}) as AnyObject}
        return json
    }

    override public func setDistanceFrom(currentPosition: Point3D) {
        self.distance = perimeter.contains(point: currentPosition) ? 0.0 : Double(currentPosition - self.center)
    }
}

public class Thing: Flare, FlarePosition {
    public var environmentId: String
    public var zoneId: String

    public var type: String
    public var position: Point3D
    public var minor: Int?

    public var distances = [Double]()
    public var inverseDistance = 0.0

    public class func loadJson(json: JSONDictionary) -> [Thing] {
        var results = [Thing]()
        for child in json.getArray(key: "things") {
            let thing = Thing(json: child)
            results.append(thing)
        }
        return results
    }

    override public init(json: JSONDictionary) {
        self.environmentId = json.getString(key: "environment")
        self.zoneId = json.getString(key: "zone")

        self.type = json.getString(key: "type")
        self.position = getPoint3D(json: json.getDictionary(key: "position"))

        super.init(json: json)

        if let minor = self.data["minor"] as? Int { self.minor = minor }
    }

    override public var description: String {
        return "\(super.description) - \(position)"
    }

    override public func parentId() -> String? {
        return zoneId
    }

    override public func toJSON() -> JSONDictionary {
        var json = super.toJSON()
        json["position"] = self.position.toJSON() as AnyObject
        return json
    }

    override public func setDistanceFrom(currentPosition: Point3D) {
        self.distance = Double(currentPosition - self.position)
    }

    public func addDistance(distance: Double) {
        distances.append(distance)
        while distances.count > 5 {
            distances.remove(at: 0)
        }
    }

    public func lastDistance() -> Double {
        if distances.count > 0 {
            return distances.last!
        }
        return -1
    }

    public func averageDistance() -> Double {
        var count = 0
        var total = 0.0

        for value in distances where value != -1 {
            total += value
            count += 1
        }

        if count == 0 {
            return -1
        }

        return total / Double(count)
    }
}

public class Device: Flare, FlarePosition {
    public var environmentId: String

    public var position: Point3D

    override public init(json: JSONDictionary) {
        self.environmentId = json.getString(key: "environment")

        self.position = getPoint3D(json: json.getDictionary(key: "position"))

        super.init(json: json)
    }

    override public var description: String {
        return "\(super.description) - \(position)"
    }

    override public func parentId() -> String? {
        return environmentId
    }

    override public func toJSON() -> JSONDictionary {
        var json = super.toJSON()
        json["position"] = self.position.toJSON() as AnyObject
        return json
    }

    public func angle() -> Double {
        if let value = self.data["angle"] as? Double {
            return value
        } else {
            return 0
        }
    }

    public func distanceTo(thing: Thing) -> Double {
        return self.position - thing.position
    }

    public func angleTo(thing: Thing) -> Double {
        let dx = thing.position.x - self.position.x
        let dy = thing.position.y - self.position.y
        let radians = Double(atan2(dy, dx))
        var degrees = radiansToDegrees(radians: radians)
        if degrees < 0 { degrees += 360.0 }
        return degrees
    }
}

public class Geofence: NSObject {
    public var latitude: Double
    public var longitude: Double
    public var radius: Double

    public init(json: JSONDictionary) {
        self.latitude = json.getDouble(key: "latitude")
        self.longitude = json.getDouble(key: "longitude")
        self.radius = json.getDouble(key: "radius")
    }

    override public var description: String {
        let latLabel = self.latitude >= 0 ? "°N" : "°S"
        let longLabel = self.latitude >= 0 ? "°E" : "°W"
        return "\(self.latitude)\(latLabel), \(self.longitude)\(longLabel), \(self.radius)m))"
    }

    // calculates the distance in meters along the Earth's surface between the geofence and the given location
    public func distanceFrom(latlong: CGPoint) -> Double {
        let lat1rad = latitude * Double.pi/180
        let lon1rad = longitude * Double.pi/180
        let lat2rad = Double(latlong.x) * Double.pi/180
        let lon2rad = Double(latlong.y) * Double.pi/180

        let dLat = lat2rad - lat1rad
        let dLon = lon2rad - lon1rad
        let a = sin(dLat/2) * sin(dLat/2) + sin(dLon/2) * sin(dLon/2) * cos(lat1rad) * cos(lat2rad)
        let c = 2 * asin(sqrt(a))
        let r = 6372.8

        return r * c
    }

    public func toJSON() -> JSONDictionary {
        return ["latitude": self.latitude as AnyObject, "longitude": self.longitude as AnyObject, "radius": self.radius as AnyObject]
    }
}

public func getRect(json: JSONDictionary) -> CGRect {
    return CGRect(origin: getPoint(json: json.getDictionary(key: "origin")), size: getSize(json: json.getDictionary(key: "size")))
}

public func getCube3D(json: JSONDictionary) -> Cube3D {
    return Cube3D(origin: getPoint3D(json: json.getDictionary(key: "origin")), size: getSize3D(json: json.getDictionary(key: "size")))
}

public func getPoint(json: JSONDictionary) -> CGPoint {
    return CGPoint(x: json.getDouble(key: "x"), y: json.getDouble(key: "y"))
}

public func getPoint3D(json: JSONDictionary) -> Point3D {
    return Point3D(x: CGFloat(json.getDouble(key: "x")),
                   y: CGFloat(json.getDouble(key: "y")),
                   z: CGFloat(json.getDouble(key: "z"))) // default is 0
}

public func getSize(json: JSONDictionary) -> CGSize {
    return CGSize(width: json.getDouble(key: "width"), height: json.getDouble(key: "height"))
}

public func getSize3D(json: JSONDictionary) -> Size3D {
    return Size3D(width: CGFloat(json.getDouble(key: "width")),
                  height: CGFloat(json.getDouble(key: "height")),
                  depth: CGFloat(json.getDouble(key: "depth"))) // default is 0
}
