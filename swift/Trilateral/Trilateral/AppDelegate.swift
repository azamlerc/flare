//
//  AppDelegate.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 3/24/15.
//  Copyright (c) 2015 Cisco. All rights reserved.
//

import UIKit
import Flare
import CoreLocation
import WatchConnectivity

// Each of the UIView(Controller)s that control the various tabs conforms to this protocol.
// When the current objects change these variables will be set, and when the objects' data
// changes the dataChanged() function will be called.
protocol FlareController {
    var currentEnvironment: Environment? { get set }
    var currentZone: Zone? { get set }
    var device: Device? { get set }
    var nearbyThing: Thing? { get set }
    
    func dataChanged()
    func animate()
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, FlareManagerDelegate, BeaconManagerDelegate /*, WCSessionDelegate */ {

    var window: UIWindow?

    var host = "localhost"
    var port = 1234
    
    let animationDelay = 0.5 // the duration of the animation in seconds
    let animationSteps = 30 // the number of times during the animation that the display is updated
    
    var defaults = UserDefaults.standard
    var flareManager = FlareManager(host: "localhost", port: 1234)
    var beaconManager = BeaconManager()
    var currentLocation: CLLocation?
    
    var allEnvironments = [Environment]()
    
    // when these are changed, the equivalent variables in the current flareController will be updated
    var currentEnvironment: Environment? { didSet(value) {
        if flareController != nil { flareController!.currentEnvironment = self.currentEnvironment }}}
    var currentZone: Zone? { didSet(value) {
        if flareController != nil { flareController!.currentZone = self.currentZone }}}
    var device: Device? { didSet(value) {
        if flareController != nil { flareController!.device = self.device }}}
    var nearbyThing: Thing? { didSet(value) {
        if flareController != nil { flareController!.nearbyThing = self.nearbyThing }}}
    
    // when the tab is changed, the new flareController should call updateFlareController()
    var flareController: FlareController? = nil
    
    // var session: WCSession?
    
    func application(_: UIApplication, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        registerDefaultsFromSettingsBundle()

        if let newHost = defaults.string(forKey: "host") { host = newHost }
        let newPort = defaults.integer(forKey: "port")
        if newPort != 0 { port = newPort }
        
        NSLog("Server: \(host):\(port)")
        NSLog("GPS: \(defaults.bool(forKey: "useGPS") ? "on" : "off")")
        NSLog("Beacons: \(defaults.bool(forKey: "useBeacons") ? "on" : "off")")
        NSLog("CMX: \(defaults.bool(forKey: "useCMX") ? "on" : "off")")
        NSLog("Compass: \(defaults.bool(forKey: "useCompass") ? "on" : "off")")
        
        print("host: \(host)")
        print("port: \(port)")
        
        flareManager = FlareManager(host: host, port: port)
        flareManager.debugSocket = false // turn on to print all Socket.IO messages
        flareManager.debugHttp = true
        
        flareManager.delegate = self
        beaconManager.delegate = self
        
        flareManager.connect()
        
        if !defaults.bool(forKey: "useGPS") { loadDefaultEnvironment() }

/*        if WCSession.isSupported() {
            session = WCSession.defaultSession()
            session!.delegate = self
            session!.activateSession()
        }
 */
        
        loadEnvironments()
        
        return true
    }

    // called at startup, and when the GPS location changes significantly
    func deviceLocationDidChange(location: CLLocation) {
        NSLog("Location: \(location.coordinate.latitude),\(location.coordinate.longitude)")
        currentLocation = location
        
        loadEnvironments()
    }
    
    @IBAction func reload() {
        loadEnvironments()
    }
    
    func loadEnvironments() {
        print("loadEnvironments")
        
        var params: JSONDictionary? = nil
        if currentLocation != nil {
            params = ["latitude":currentLocation!.coordinate.latitude, "longitude":currentLocation!.coordinate.longitude]
        }
        
        self.flareManager.loadEnvironments(params: params, loadDevices: false) { (environments) -> () in // load environment for current location
            if environments.count > 0 {
                self.allEnvironments = environments
                self.loadEnvironment(environment: environments[0])
            } else {
                self.flareManager.loadEnvironments(params: nil, loadDevices: false) { (environments) -> () in // load all environments
                    if environments.count > 0 {
                        self.allEnvironments = environments
                        NSLog("No environments found nearby, using default environment.")
                        self.allEnvironments = environments
                        self.loadEnvironment(environment: environments[0])
                    } else {
                        NSLog("No environments found.")
                    }
                }
            }
        }
    }
    
    func loadDefaultEnvironment() {
        self.flareManager.loadEnvironments(params: nil, loadDevices: false) { (environments) -> () in // load all environments
            if environments.count > 0 {
                self.allEnvironments = environments
                if let environmentId = self.defaults.string(forKey: "environmentId"),
                    let environment = self.environmentWithId(environments: environments, environmentId: environmentId)
                {
                    NSLog("Using saved environment.")
                    self.loadEnvironment(environment: environment)
                } else {
                    NSLog("Using first environment.")
                    self.loadEnvironment(environment: environments[0])
                }
            } else {
                NSLog("No environments found.")
            }
        }
    }
    
    func environmentWithId(environments: [Environment], environmentId: String) -> Environment? {
        for environment in environments {
            if environment.id == environmentId {
                return environment
            }
        }
        return nil
    }
    
    func loadEnvironment(environment: Environment) {
        self.currentEnvironment = environment
        self.flareManager.subscribe(flare: environment, all: true)
        NSLog("Current environment: \(environment.name)")
        
        defaults.set(environment.id, forKey: "environmentId")
        
        self.flareManager.getCurrentDevice(environmentId: environment.id, template: self.deviceTemplate()) { (device) -> () in
            self.loadDevice(value: device)
        }
        
        self.beaconManager.loadEnvironment(value: environment)
        if defaults.bool(forKey: "useBeacons") { self.beaconManager.start() }
        if defaults.bool(forKey: "useGPS") { self.beaconManager.startMonitoringLocation() }
        if defaults.bool(forKey: "useCompass") { self.beaconManager.startUpdatingHeading() }
        
        self.updateFlareController()

    }
    
    func nextEnvironment() {
        if allEnvironments.count > 0 && currentEnvironment != nil {
            let index = allEnvironments.index(of: currentEnvironment!)
            let next = (index! + 1) % allEnvironments.count
            let nextEnvironment = allEnvironments[next]
            loadEnvironment(environment: nextEnvironment)
        }
    }
    
    func previousEnvironment() {
        if allEnvironments.count > 0 && currentEnvironment != nil {
            let index = allEnvironments.index(of: currentEnvironment!)
            let previous = (index! - 1 + allEnvironments.count) % allEnvironments.count
            let previousEnvironment = allEnvironments[previous]
            loadEnvironment(environment: previousEnvironment)
        }
    }
    
    func loadDevice(value: Device?) {
        if let device = value {
            self.device = device
            // already subscribing to all objects
            // self.flareManager.subscribe(device)
            
            loadCurrentZone()
            loadNearbyThing()
            // loadMacAddress() // this is done server-side
        }
    }
    
    func loadCurrentZone() {
        if currentEnvironment != nil && device != nil {
            flareManager.getCurrentZone(environment: currentEnvironment!, device: device!) { zone in
                self.currentZone = zone
            }
        }
    }
    
    func loadNearbyThing() {
        if currentEnvironment != nil && device != nil {
            flareManager.getNearestThing(environment: currentEnvironment!, device: device!) { thing in
                self.nearbyThing = thing
            }
        }
    }
    
    func loadMacAddress() {
        if device != nil {
            if let mac = device!.data["mac"] as? String {
                if mac == "02:00:00:00:00:00" { // bogus
                    getMacAddress()
                }
            } else {
                getMacAddress()
            }
        }
    }
    
    func getMacAddress() {
        flareManager.getMacAddress(host: host, port: 80) { mac in
            NSLog("mac: \(mac)")
            self.flareManager.setData(flare: self.device!, key: "mac", value: mac as AnyObject, sender: self.device!)
        }
    }
    
    func updateFlareController() {
        if flareController != nil {
            flareController!.currentEnvironment = self.currentEnvironment
            flareController!.currentZone = self.currentZone
            flareController!.device = self.device
            flareController!.nearbyThing = self.nearbyThing
        }
    }
    
    func dataChanged() {
        if flareController != nil {
            flareController!.dataChanged()
        }
    }
    
    func animate() {
        if flareController != nil {
            flareController!.animate()
        }
    }
    
    // returns a template used for creating new device objects:
    // name: Andrew's iPhone
    // description: iPhone, iOS 9.2
    // data: {}
    // postion: {"x":0, "y":0}
    func deviceTemplate() -> JSONDictionary {
        let uidevice = UIDevice.current
        let name = uidevice.name
        let description = "\(uidevice.model), iOS \(uidevice.systemVersion)"
        return ["name":name, "description":description, "data":JSONDictionary(), "position":["x":0, "y":0]]
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        if defaults.bool(forKey: "useBeacons") { beaconManager.stop() }
        if defaults.bool(forKey: "useGPS") { beaconManager.stopMonitoringLocation() }
        if defaults.bool(forKey: "useCompass") { beaconManager.stopUpdatingHeading() }
        
        // not necessary to unsubscribe as disconnecting will take care of that
        flareManager.disconnect()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {

    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("applicationDidBecomeActive")

        flareManager.connect()
        
        if currentLocation != nil {
            loadEnvironments() // reload the data and resubscribe
        }
        
        if defaults.bool(forKey: "useBeacons") { beaconManager.start() }
        if defaults.bool(forKey: "useGPS") { beaconManager.startMonitoringLocation() }
        if defaults.bool(forKey: "useCompass") { beaconManager.startUpdatingHeading() }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func devicePositionDidChange(position: Point3D) {
        if device != nil {
            animateFlare(flare: device!, oldPosition: device!.position, newPosition: position)
            flareManager.setPosition(flare: device!, position: position, sender: nil)
            // sendMessage(["position": position.toJSON()])
            
            if nearbyThing != nil {
                let distance = device!.distanceTo(thing: nearbyThing!)
                let brightness = 1.0 - (distance)
                if brightness > 0 {
                    setDoubleValue(value: brightness, key: "brightness", precision: 0.1, flare: nearbyThing!)
                }
            }
        }
    }
    
    // sets the double value for the given flare, rounded to the given precision, only if it has changed
    func setDoubleValue(value: Double, key: String, precision: Double, flare: Flare) {
        let roundedValue = value.roundTo(precision: precision)
        var shouldChange = false
        
        if let oldValue = flare.data[key] as? Double {
            shouldChange = oldValue != roundedValue
        } else {
            shouldChange = true
        }

        if shouldChange {
            flare.data[key] = roundedValue
            flareManager.setData(flare: flare, key: key, value: roundedValue as AnyObject, sender: device!)
            dataChanged()
        }
    }
    
    func deviceAngleDidChange(angle: Double) {
        if device != nil {
            if angle != device!.angle() {
                // NSLog("Angle: \(angle)")
                animateAngle(flare: device!, oldAngle: device!.angle(), newAngle: angle)
                flareManager.setData(flare: device!, key: "angle", value: angle as AnyObject, sender: device!)
                dataChanged()
            }
        }
    }
    
    func didReceiveData(flare: Flare, data: JSONDictionary, sender: Flare?) {
        dataChanged()
    }
    
    func didReceivePosition(flare: Flare, oldPosition: Point3D, newPosition: Point3D, sender: Flare?) {
        if defaults.bool(forKey: "useCMX") || true {
            NSLog("\(flare.name) position: \(newPosition)")
            animateFlare(flare: flare as! FlarePosition, oldPosition: oldPosition, newPosition: newPosition)
        }
    }
    
    var didEnter = false // for half a second after an enter message arrives, ignore exit messages
    
    func enter(zone: Zone, device: Device) {
        NSLog("\(zone.name) enter: \(device.name)")
        self.currentZone = zone
        didEnter = true
        delay(duration: 0.5) { self.didEnter = false }
    }
    
    func exit(zone: Zone, device: Device) {
        NSLog("\(zone.name) exit: \(device.name)")
        if !didEnter {
            self.currentZone = nil
        } else {
            NSLog("Ignoring exit message!")
        }
    }
    
    func near(thing: Thing, device: Device, distance: Double) {
        NSLog("near: \(thing.name)")
        
        if device == self.device && thing != self.nearbyThing {
            nearbyThing = thing
            
            // already subscribing to all objects
            // flareManager.subscribe(thing)
            flareManager.getData(flare: thing)
            flareManager.getPosition(flare: thing)
            
        }
    }
    
    func far(thing: Thing, device: Device) {
        NSLog("far: \(thing.name)")

        if device == self.device && thing == self.nearbyThing {
            
            // already subscribing to all objects
            // flareManager.unsubscribe(thing)
            
            // stay paired even when moving away
            // nearbyThing = nil
        }
    }

    func handleAction(flare: Flare, action: String, sender: Flare?) {
        
    }
    
    func animateFlare( flare: FlarePosition, oldPosition: Point3D, newPosition: Point3D) {
        var animatedFlare = flare
        if oldPosition == newPosition { return }
        
        let dx = (newPosition.x - oldPosition.x) / CGFloat(animationSteps)
        let dy = (newPosition.y - oldPosition.y) / CGFloat(animationSteps)
        let dz = (newPosition.z - oldPosition.z) / CGFloat(animationSteps)
        
        animatedFlare.position = oldPosition
        delayLoop(duration: animationDelay, steps: animationSteps) { i in
            animatedFlare.position = Point3D(x: oldPosition.x + CGFloat(i) * dx,
                                     y: oldPosition.y + CGFloat(i) * dy,
                                     z: oldPosition.z + CGFloat(i) * dz)
            self.animate()
            if i == self.animationSteps - 1 { self.dataChanged() }
        }
    }
    
    func animateAngle(flare: Device, oldAngle: Double, newAngle: Double) {
        var oldAngleAdjusted = oldAngle
        if oldAngle == newAngle { return }
        
        // prevent the compass from spinning the wrong way
        if newAngle - oldAngleAdjusted > 180.0 {
            oldAngleAdjusted += 360.0
        } else if newAngle - oldAngleAdjusted < -180.0 {
            oldAngleAdjusted -= 360.0
        }
        
        let delta = (newAngle - oldAngleAdjusted) / Double(animationSteps)
        
        flare.data["angle"] = oldAngle
        delayLoop(duration: animationDelay, steps: animationSteps) { i in
            flare.data["angle"] = oldAngleAdjusted + Double(i) * delta
            self.animate()
            if i == self.animationSteps - 1 { self.dataChanged() }
        }
    }
    
    func setNearbyThingData(key: String, value: AnyObject) {
        if nearbyThing != nil {
            nearbyThing!.data[key] = value
            flareManager.setData(flare: nearbyThing!, key: key, value: value, sender: device)
            dataChanged()
        }
    }

    func registerDefaultsFromSettingsBundle() {
        defaults.synchronize()
        
        let settingsBundle: NSString = Bundle.main.path(forResource: "Settings", ofType: "bundle")! as NSString
        if(settingsBundle.contains("")){
            NSLog("Could not find Settings.bundle");
            return;
        }
        let settings: NSDictionary = NSDictionary(contentsOfFile: settingsBundle.appendingPathComponent("Root.plist"))!
        var defaultsToRegister = [String:AnyObject]()
        let prefSpecifierArray = settings.object(forKey: "PreferenceSpecifiers") as! NSArray

        for prefItem in prefSpecifierArray {
            if let key = (prefItem as AnyObject).object(forKey: "Key") as? String {
                let defaultValue:AnyObject? = (prefItem as AnyObject).object(forKey: "DefaultValue") as AnyObject?
                defaultsToRegister[key] = defaultValue
            }
        }

        defaults.register(defaults: defaultsToRegister)
        defaults.synchronize()
    }
/*
    func sendMessage(message: JSONDictionary?) {
        if (session != nil && message != nil) {
            NSLog("Sending: \(message!)")
            session!.sendMessage(message!, replyHandler: nil, errorHandler: nil)
        }
    }
    
    func session(session: WCSession, didReceiveMessage incomingMessage: [String : AnyObject], replyhandler: @escaping ([String : AnyObject]) -> Void) {
        NSLog("Received message: \(incomingMessage)")

        var message: JSONDictionary? = nil
        if let get = incomingMessage["get"] as? String {
            
            NSLog("Received: \(incomingMessage)")
            
            if (get == "position") {
                message = positionMessage()
            } else if (get == "things") {
                message = thingsMessage()
            }
            
            if message != nil {
                NSLog("Replying: \(message!)")
                replyHandler(message!)
            }
        } else if let data = incomingMessage["data"] as? JSONDictionary,
            thingId = data["thing"] as? String,
            thing = flareManager.flareIndex[thingId] as? Thing,
            key = data["key"] as? String,
            value = data["value"] as? String
        {
            NSLog("Setting \(thing.name) \(key) \(value)")
            flareManager.setData(thing, key: key, value: value, sender: device)
        }
    }
    
    func thingsMessage() -> JSONDictionary? {
        if let zone = currentZone {
            return ["things": zone.things.map({$0.toJSON()})]
        } else {
            return nil
        }
    }
    
    func positionMessage() -> JSONDictionary? {
        if let position = device?.position {
            return ["position": position.toJSON()]
        } else {
            return nil
        }
    }
*/


}

extension Thing {
    func imageName() -> String? {
        if let color = data["color"] as? String {
            return "\(name.lowercased())-\(color)"
        }
        return nil
    }
}

