//
//  FlareManager.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 3/25/15.
//  Copyright (c) 2015 Cisco. All rights reserved.
//

import CoreGraphics
import CoreLocation
import Foundation

public protocol BeaconManagerDelegate: class {
    func devicePositionDidChange(position: Point3D)
    func deviceLocationDidChange(location: CLLocation)
    func deviceAngleDidChange(angle: Double)
}

public class BeaconManager: NSObject, CLLocationManagerDelegate {

    let beaconDebug = false

    public weak var delegate: BeaconManagerDelegate?
    public var locationManager = CLLocationManager()
    public var region: CLBeaconRegion?

    public var currentLatlong: CLLocation?

    public var environment: Environment?
    public var beacons = [Int: Thing]()
    public var linearBeacons = [Thing]()

    override public init() {
        super.init()

        self.locationManager.delegate = self
        // self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.requestAlwaysAuthorization()
    }

    public func loadEnvironment(value: Environment) {
        self.environment = value

        if environment != nil {
            if let uuidString = environment!.uuid {
                let uuid = NSUUID(uuidString: uuidString)
                region = CLBeaconRegion(proximityUUID: uuid! as UUID, identifier: environment!.name)
                beacons = environment!.beacons()
                linearBeacons = [Thing](beacons.values)
                linearBeacons.sort(by: { $0.minor ?? 0 > $1.minor ?? 0 })
                if beaconDebug { NSLog("Looking for \(beacons.count) beacons.") }
            } else {
                NSLog("Environment has no uuid.")
            }
        }
    }

    public func start() {
        if region != nil {
            self.locationManager.startRangingBeacons(in: region!)
        }
    }

    public func stop() {
        if region != nil {
            self.locationManager.stopRangingBeacons(in: region!)
        }
    }

    public func startMonitoringLocation() {
        self.locationManager.startMonitoringSignificantLocationChanges()
    }

    public func stopMonitoringLocation() {
        self.locationManager.stopMonitoringSignificantLocationChanges()
    }

    public func startUpdatingHeading() {
        self.locationManager.startUpdatingHeading()
    }

    public func stopUpdatingHeading() {
        self.locationManager.stopUpdatingHeading()
    }

    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: NSLog("Not determined")
        case .restricted: NSLog("Restricted")
        case .denied: NSLog("Denied")
        case .authorizedAlways: NSLog("Authorized Always")
        case .authorizedWhenInUse: NSLog("Authorized When In Use")
        }
    }

    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // NSLog("Did update locations")
        if let location = locations.last {
            // NSLog("Location: \(location)")
            currentLatlong = location

            if delegate != nil {
                delegate!.deviceLocationDidChange(location: location)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didRangeBeacons clbeacons: [CLBeacon], in region: CLBeaconRegion) {
        var clBeaconIndex = [Int: CLBeacon]()

        if beaconDebug { NSLog("Found \(clbeacons.count) beacons.") }

        for clbeacon in clbeacons {
            let index = clbeacon.major.intValue * 10000 + clbeacon.minor.intValue
            if beaconDebug { NSLog("Saw beacon: \(clbeacon.major.intValue) - \(clbeacon.minor.intValue)") }
            clBeaconIndex[index] = clbeacon
        }

        for (index, beacon) in beacons {
            if let clbeacon = clBeaconIndex[index] {
                if beaconDebug { NSLog("Found beacon: \(beacon.name)") }
                beacon.addDistance(distance: clbeacon.accuracy)
            } else {
                if beaconDebug { NSLog("Couldn't find beacon: \(beacon.name) (\(index))") }
                beacon.addDistance(distance: -1.0) // the beacon was not seen this time
            }
        }

        if delegate != nil {
            let position = weightedLocation(average: false)
            if !position.x.isNaN && !position.y.isNaN {
                delegate!.devicePositionDidChange(position: position.roundTo(precision: 0.01))
            }
        }
    }

    var angleDelay = 1.0
    var lastAngleTime = NSDate()
    var lastAngle = -1.0

    public func locationManager(manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let newAngle = newHeading.magneticHeading.roundTo(precision: 5.0)

        if newAngle != lastAngle && lastAngleTime.timeIntervalSinceNow < -angleDelay {
            lastAngleTime = NSDate()
            lastAngle = newAngle
            delegate!.deviceAngleDidChange(angle: newAngle)
        }
    }

    // the average position of all nearby beacons,
    // weighted according to the inverse of the square of the distance
    public func weightedLocation(average: Bool) -> Point3D {
        var total = 0.0
        var x = 0.0
        var y = 0.0
        var z = 0.0

        for (_, beacon) in beacons {
            let distance = average ? beacon.averageDistance() : beacon.lastDistance()
            if distance > 0 {
                beacon.inverseDistance = 1.0 / (distance * distance)
            } else {
                beacon.inverseDistance = -1
            }
        }

        var sortedBeacons = [Thing](beacons.values)
        sortedBeacons.sort { $0.inverseDistance > $1.inverseDistance }

        for beacon in sortedBeacons where beacon.inverseDistance != -1 {
            let weight = beacon.inverseDistance
            x += Double(beacon.position.x) * weight
            y += Double(beacon.position.y) * weight
            z += Double(beacon.position.z) * weight
            total += weight
        }

        let result = Point3D(x: x / total, y: y / total, z: z / total)
        return result
    }
}
