//
//  FlareManager.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 3/25/15.
//  Copyright (c) 2015 Cisco. All rights reserved.
//

import Foundation
import CoreGraphics
import SocketIO

public protocol FlareManagerDelegate {
    func didReceiveData(flare: Flare, data: JSONDictionary, sender: Flare?)
    func didReceivePosition(flare: Flare, oldPosition: Point3D, newPosition: Point3D, sender: Flare?)
    func handleAction(flare: Flare, action: String, sender: Flare?)
    func enter(zone: Zone, device: Device)
    func exit(zone: Zone, device: Device)
    func near(thing: Thing, device: Device, distance: Double)
    func far(thing: Thing, device: Device)
}

public class FlareManager: APIManager {
    
    public var debugSocket = true
    
    public var delegate: FlareManagerDelegate?
    public var socketManager: SocketManager
    public var socket: SocketIOClient
    public var flareIndex = [String:Flare]()
    
    public init(host: String, port: Int) {
        self.socketManager = SocketManager(socketURL: URL(string: "http://\(host):\(port)")!, config: [.log(true), .compress])
        self.socket = self.socketManager.defaultSocket
        // socket = SocketIOClient(socketURL: "\(host):\(port)", options: [])

        super.init()
        
        self.server = "http://\(host):\(port)" // TODO: support https and subpaths
    }
    
    public func connect() {
        self.addHandlers()
        self.socket.connect()
    }
    
    public func disconnect() {
        self.socket.disconnect()
    }
    
    public func getMacAddress(host: String, port: Int, handler: @escaping (String) -> ()) {
        sendRequest(uri: "http://\(host):\(port)/mac/mac.php") { json in
            if let mac = json["result"] as? String {
                handler(mac)
            }
        }
    }
    
    var requests = 0
    
    func startRequest() {
        requests += 1
    }
    
    func finishRequest(handler: @escaping () -> ()) {
        requests -= 1
        if requests == 0 {
            handler()
        }
    }

    // Asynchronously loads all zones and things for one environment, and then calls the handler.
    public func loadEnvironment(environment: Environment, handler: @escaping () -> ()) {
        self.startRequest()
        self.listZones(environmentId: environment.id) {(jsonArray) -> () in
            for json in jsonArray {
                let zone = Zone(json: json)
                environment.zones.append(zone)
                self.addToIndex(flare: zone)
                
                self.startRequest()
                self.listThings(environmentId: environment.id, zoneId: zone.id) {(jsonArray) -> () in
                    for json in jsonArray {
                        let thing = Thing(json: json)
                        zone.things.append(thing)
                        self.addToIndex(flare: thing)
                    }
                    self.finishRequest(handler: handler)
                }
            }
            self.finishRequest(handler: handler)
        }
    }
    
    // Asynchronously loads the complete environment / zone / thing / device hierarchy, and then calls the handler.
    public func loadEnvironments(handler: @escaping ([Environment]) -> ()) {
        loadEnvironments(params: nil, loadDevices: true, handler: handler)
    }
    
    var environmentsRequests = 0
    
    func startEnvironmentsRequests() {
        environmentsRequests += 1
    }
    
    func finishEnvironmentsRequest(handler: @escaping ([Environment]) -> (), environments: [Environment]) {
        environmentsRequests -= 1
        if environmentsRequests == 0 {
            handler(environments)
        }
    }
    
    // Asynchronously loads the complete environment / zone / thing / device hierarchy, and then calls the handler.
    // params is optional and should contain latitude and longitude
    public func loadEnvironments(params: JSONDictionary?, loadDevices: Bool, handler: @escaping ([Environment]) -> ()) {
        var environments = [Environment]()
        
        self.startEnvironmentsRequests()
        self.listEnvironments(params: params) {(jsonArray) -> () in
            for json in jsonArray {
                let environment = Environment(json: json)
                environments.append(environment)
                self.addToIndex(flare: environment)
                
                self.startEnvironmentsRequests()
                self.listZones(environmentId: environment.id) {(jsonArray) -> () in
                    for json in jsonArray {
                        let zone = Zone(json: json)
                        environment.zones.append(zone)
                        self.addToIndex(flare: zone)
                        
                        self.startEnvironmentsRequests()
                        self.listThings(environmentId: environment.id, zoneId: zone.id) {(jsonArray) -> () in
                            for json in jsonArray {
                                let thing = Thing(json: json)
                                zone.things.append(thing)
                                self.addToIndex(flare: thing)
                            }
                            zone.things.sort() {$1.name > $0.name}
                            self.finishEnvironmentsRequest(handler: handler, environments: environments)
                        }
                    }
                    environment.zones.sort() {$1.name > $0.name}
                    self.finishEnvironmentsRequest(handler: handler, environments: environments)
                }
                
                if loadDevices {
                    self.startEnvironmentsRequests()
                    self.listDevices(environmentId: environment.id) {(jsonArray) -> () in
                        for json in jsonArray {
                            let device = Device(json: json)
                            environment.devices.append(device)
                            self.addToIndex(flare: device)
                        }
                        environment.devices.sort() {$1.name > $0.name}
                        self.finishEnvironmentsRequest(handler: handler, environments: environments)
                    }
                }
            }
            environments.sort() {$1.name > $0.name}
            self.finishEnvironmentsRequest(handler: handler, environments: environments)
        }
    }

    public func getCurrentZone(environment: Environment, device: Device, handler: @escaping (Zone) -> ()) {
        listZones(environmentId: environment.id, point: device.position) { zones in
            if let json = zones.first, let id = json["_id"] as? String, let zone = self.flareIndex[id] as? Zone {
                handler(zone)
            }
        }
    }
    
    public func getNearestThing(environment: Environment, device: Device, handler: @escaping (Thing) -> ()) {
        getDevice(deviceId: device.id, environmentId: environment.id) { json in
            if let nearest = json["nearest"] as? String, let thing = self.flareIndex[nearest] as? Thing {
                handler(thing)
            }
        }
    }
    
    // used to safely modify a Flare object on the server
    // the handler takes the current JSON as input, and should return the modified JSON as output
    public func modifyFlare(flare: Flare, handler: @escaping (JSONDictionary) -> (JSONDictionary)) {
        getFlare(flare: flare) {json in
            NSLog("Current  \(flare): \(json)")
            let modifiedJson = handler(json)
            NSLog("Modified \(flare): \(modifiedJson)")
            self.updateFlare(flare: flare, json: modifiedJson) {json in }
        }
    }
    
    // gets the up-to-date JSON for a Flare object from the server
    public func getFlare(flare: Flare, handler: @escaping (JSONDictionary) -> ()) {
        if let environment = flare as? Environment {
            getEnvironment(environmentId: environment.id, handler: handler)
        } else if let zone = flare as? Zone {
            getZone(zoneId: zone.id, environmentId: zone.environmentId, handler: handler)
        } else if let thing = flare as? Thing {
            getThing(thingId: thing.id, environmentId: thing.environmentId, zoneId: thing.zoneId, handler: handler)
        } else if let device = flare as? Device {
            getDevice(deviceId: device.id, environmentId: device.environmentId, handler: handler)
        }
    }
    
    // creates a new Flare object on the server
    // if the flare is nil, creates an environment
    // if the flare is an environment, creates a zone
    // if the flare is a zone, creates a thing
    public func newFlare(flare: Flare?, json: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        var template = json
        if flare == nil {
            if template["perimeter"] == nil { template["perimeter"] = ["origin":["x":0, "y":0], "size":["width":10, "height":10]] as AnyObject }
            newEnvironment(environment: template, handler: handler)
        } else if let environment = flare as? Environment {
            if template["perimeter"] == nil { template["perimeter"] = ["origin":["x":0, "y":0], "size":["width":5, "height":5]] as AnyObject }
            newZone(environmentId: environment.id, zone:  template, handler: handler)
        } else if let zone = flare as? Zone {
            if template["position"] == nil { template["position"] = ["x":0, "y":0] as AnyObject }
            newThing(environmentId: zone.environmentId, zoneId: zone.id, thing:  template, handler: handler)
        }
    }
    
    // updates the JSON for a Flare object on the server
    public func updateFlare(flare: Flare, json: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        if let environment = flare as? Environment {
            updateEnvironment(environmentId: environment.id, environment: json, handler: handler)
        } else if let zone = flare as? Zone {
            updateZone(zoneId: zone.id, environmentId: zone.environmentId, zone: json, handler: handler)
        } else if let thing = flare as? Thing {
            updateThing(thingId: thing.id, environmentId: thing.environmentId, zoneId: thing.zoneId, thing: json, handler: handler)
        } else if let device = flare as? Device {
            updateDevice(deviceId: device.id, environmentId: device.environmentId, device: json, handler: handler)
        }
    }
    
    // deletes a Flare object on the server
    public func deleteFlare(flare: Flare, handler: @escaping (JSONDictionary) -> ()) {
        flareIndex.removeValue(forKey: flare.id)
        
        if let environment = flare as? Environment {
            deleteEnvironment(environmentId: environment.id, handler: handler)
        } else if let zone = flare as? Zone {
            deleteZone(zoneId: zone.id, environmentId: zone.environmentId, handler: handler)
        } else if let thing = flare as? Thing {
            deleteThing(thingId: thing.id, environmentId: thing.environmentId, zoneId: thing.zoneId, handler: handler)
        } else if let device = flare as? Device {
            deleteDevice(deviceId: device.id, environmentId: device.environmentId, handler: handler)
        }
    }
    
    public func addToIndex(flare: Flare) {
        self.flareIndex[flare.id] = flare
    }
    
    public func flareWithName(array: [Flare], name: String) -> Flare? {
        for flare in array {
            if flare.name == name {
                return flare
            }
        }
        return nil
    }
    
    public func flareForMessage(message: JSONDictionary) -> Flare? {
        if let id = message["thing"] as? String {
            return flareIndex[id];
        } else if let id = message["device"] as? String {
            return flareIndex[id];
        } else if let id = message["zone"] as? String {
            return flareIndex[id];
        } else if let id = message["environment"] as? String {
            return flareIndex[id];
        } else {
            return nil
        }
    }
    
    public func environmentForFlare(flare: Flare) -> Environment? {
        if let environment = flare as? Environment {
            return environment
        } else if let zone = flare as? Zone, let environment = flareIndex[zone.environmentId] as? Environment {
            return environment
        } else if let thing = flare as? Thing, let environment = flareIndex[thing.environmentId] as? Environment {
            return environment
        } else if let device = flare as? Device, let environment = flareIndex[device.environmentId] as? Environment {
            return environment
        } else {
            return nil
        }
    }
    
    // MARK: Environments
    
    public func listEnvironments(handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments")
            {json in handler(json as! JSONArray)}
    }
    
    // return environments filtered by parameters
    // latitude, longitude: filter environments whose geofence contains the given point
    // key, value: filter environments whose data contains the given key/value pair
    public func listEnvironments(params: JSONDictionary?, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments", params: params)
            {json in handler(json as! JSONArray)}
    }

    public func newEnvironment(environment: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments", params: nil, method: .POST, message: environment)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getEnvironment(environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func updateEnvironment(environmentId: String, environment: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)", params: nil, method: .PUT, message: environment)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func deleteEnvironment(environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)", params: nil, method: .DELETE, message: nil)
            {json in handler(json as! JSONDictionary)}
    }
    
    // MARK: Zones
    
    public func listZones(environmentId: String, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones")
            {json in handler(json as! JSONArray)}
    }
    
    // return only zones in the environment containing the given point
    public func listZones(environmentId: String, point: Point3D, handler: @escaping (JSONArray) -> ()) {
        let params = point.toJSON()
        listZones(environmentId: environmentId, params: params, handler: handler)
    }
    
    // return zones filtered by parameters
    // x, y: filter zones whose perimeter contains the given point
    // key, value: filter zones whose data contains the given key/value pair
    public func listZones(environmentId: String, params: JSONDictionary?, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones", params: params)
            {json in handler(json as! JSONArray)}
    }
    
    public func newZone(environmentId: String, zone: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones", params: nil, method: .POST, message: zone)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getZone(zoneId: String, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func updateZone(zoneId: String, environmentId: String, zone: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)", params: nil, method: .PUT, message: zone)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func deleteZone(zoneId: String, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)", params: nil, method: .DELETE, message: nil)
            {json in handler(json as! JSONDictionary)}
    }
    
    // MARK: Things
    
    public func listThings(environmentId: String, zoneId: String, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things")
            {json in handler(json as! JSONArray)}
    }
    
    // return things filtered by parameters
    // x, y, distance: filter things whose position is within distance from the given point
    // key, value: filter things whose data contains the given key/value pair
    public func listThings(environmentId: String, zoneId: String, params: JSONDictionary?, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things", params: params)
            {json in handler(json as! JSONArray)}
    }
    
    public func newThing(environmentId: String, zoneId: String, thing: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things", params: nil, method: .POST, message: thing)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getThing(thingId: String, environmentId: String, zoneId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things/\(thingId)")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getThingData(thingId: String, environmentId: String, zoneId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things/\(thingId)/data")
            {json in handler(json as! JSONDictionary)}
    }

    public func getThingDataValue(thingId: String, environmentId: String, zoneId: String, key: String, handler:@escaping (AnyObject) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things/\(thingId)/data/\(key)", handler: handler)
    }
    
    public func getThingPosition(thingId: String, environmentId: String, zoneId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things/\(thingId)/position")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func updateThing(thingId: String, environmentId: String, zoneId: String, thing: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things/\(thingId)", params: nil, method: .PUT, message: thing)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func deleteThing(thingId: String, environmentId: String, zoneId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/zones/\(zoneId)/things/\(thingId)", params: nil, method: .DELETE, message: nil)
            {json in handler(json as! JSONDictionary)}
    }
    
    // MARK: User Devices
    
    public func listDevices(environmentId: String, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices")
            {json in handler(json as! JSONArray)}
    }
    
    // return things filtered by parameters
    // x, y, distance: filter things whose position is within distance from the given point
    // key, value: filter things whose data contains the given key/value pair
    public func listDevices(environmentId: String, params: JSONDictionary?, handler: @escaping (JSONArray) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices", params: params)
            {json in handler(json as! JSONArray)}
    }

    public func newDevice(environmentId: String, device: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices", params: nil, method: .POST, message: device)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getDevice(deviceId: String, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices/\(deviceId)")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getDeviceData(deviceId: String, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices/\(deviceId)/data")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func getDeviceDataValue(deviceId: String, environmentId: String, key: String, handler: @escaping (AnyObject) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices/\(deviceId)/data/\(key)", handler: handler)
    }
    
    public func getDevicePosition(deviceId: String, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices/\(deviceId)/position")
            {json in handler(json as! JSONDictionary)}
    }
    
    public func updateDevice(deviceId: String, environmentId: String, device: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices/\(deviceId)", params: nil, method: .PUT, message: device)
            {json in handler(json as! JSONDictionary)}
    }
    
    public func deleteDevice(deviceId: String, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        sendRequest(uri: "environments/\(environmentId)/devices/\(deviceId)", params: nil, method: .DELETE, message: nil)
            {json in handler(json as! JSONDictionary)}
    }
    
    // MARK: New or Update helpers
    // if the object already exists in the index then update it, otherwise create it
    
    public func newOrUpdateEnvironment(environment: JSONDictionary, handler: @escaping (JSONDictionary) -> ()) {
        if let id = environment["_id"] as? String, let _ = flareIndex[id] as? Environment {
            updateEnvironment(environmentId: id, environment: environment, handler: handler)
        } else {
            newEnvironment(environment: environment, handler: handler)
        }
    }
    
    public func newOrUpdateZone(zone: JSONDictionary, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        if let id = zone["_id"] as? String, let _ = flareIndex[id] as? Zone {
            updateZone(zoneId: id, environmentId: environmentId, zone: zone, handler: handler)
        } else {
            newZone(environmentId: environmentId, zone: zone, handler: handler)
        }
    }
    
    public func newOrUpdateThing(thing: JSONDictionary, environmentId: String, zoneId: String, handler: @escaping (JSONDictionary) -> ()) {
        if let id = thing["_id"] as? String, let _ = flareIndex[id] as? Thing {
            updateThing(thingId: id, environmentId: environmentId, zoneId: zoneId, thing: thing, handler: handler)
        } else {
            newThing(environmentId: environmentId, zoneId: zoneId, thing: thing, handler: handler)
        }
    }
    
    public func newOrUpdateDevice(device: JSONDictionary, environmentId: String, handler: @escaping (JSONDictionary) -> ()) {
        if let id = device["_id"] as? String, let _ = flareIndex[id] as? Device {
            updateDevice(deviceId: id, environmentId: environmentId, device: device, handler: handler)
        } else {
            newDevice(environmentId: environmentId, device: device, handler: handler)
        }
    }
    
    // tries to find an existing device object in the current environment
    // if one is not found, creates a new device object
    public func getCurrentDevice(environmentId: String, template: JSONDictionary, handler: @escaping (Device?) -> ()) {
        self.savedDevice(environmentId: environmentId) { (device) -> () in
            if device != nil {
                handler(device)
            } else {
                self.newDeviceObject(environmentId: environmentId, template: template) { (device) -> () in
                    if device != nil {
                        handler(device)
                    }
                }
            }
        }
    }
    
    // looks for an existing device object in the current environment, and if found calls the handler with it
    public func savedDevice(environmentId: String, handler: @escaping (Device?) -> ()) {
        if let deviceId = UserDefaults.standard.string(forKey: "\(environmentId)-deviceId") {
            self.getDevice(deviceId: deviceId, environmentId: environmentId) { (json) -> () in
                if let _ = json["_id"] as? String {
                    if let deviceEnvironment = json["environment"] as? String {
                        if deviceEnvironment == environmentId {
                            let device = Device(json: json)
                            self.addToIndex(flare: device)
                            
                            NSLog("Found existing device: \(device.name)")
                            handler(device)
                        } else {
                            // NSLog("Device in wrong environment")
                            handler(nil)
                        }
                    } else {
                        // NSLog("Device has no environment")
                        handler(nil)
                    }
                } else {
                    // NSLog("Device not found")
                    handler(nil)
                }
            }
        } else {
            // NSLog("No saved device")
            handler(nil)
        }
    }
    
    // creates a new device object using the default values in the template
    public func newDeviceObject(environmentId: String, template: JSONDictionary, handler: @escaping (Device?) -> ()) {
        newDevice(environmentId: environmentId, device: template) { (json) -> () in
            let device = Device(json: json)
            self.addToIndex(flare: device)
            
            UserDefaults.standard.set(device.id, forKey: "\(environmentId)-deviceId")
            NSLog("Created new device: \(device.name)")
            handler(device)
        }
    }
    
    // MARK: SocketIO sent
    
    public func emit(event: String, message: JSONDictionary) {
        if debugSocket { NSLog("\(event): \(message)") }
        socket.emit(event, message)
    }
    
    public func subscribe(flare: Flare) {
        subscribe(flare: flare, all: false)
    }
    
    public func subscribe(flare: Flare, all: Bool) {
        var message = flare.flareInfo
        if all { message["all"] = true as AnyObject }
        emit(event: "subscribe", message: message)
    }
    
    public func unsubscribe(flare: Flare) {
        let message = flare.flareInfo
        emit(event: "unsubscribe", message: message)
    }
    
    public func getData(flare: Flare) {
        let message = flare.flareInfo
        emit(event: "getData", message: message)
    }
    
    /// Gets one key/value pair of data for an object
    public func getData(flare: Flare, key: String) {
        var message = flare.flareInfo
        message["key"] = key as AnyObject
        emit(event: "getData", message: message)
    }
    
    public func setData(flare: Flare, key: String, value: AnyObject, sender: Flare?) {
        var message = flare.flareInfo
        message["key"] = key as AnyObject
        message["value"] = value
        if sender != nil { message["sender"] = sender!.id as AnyObject }
        emit(event: "setData", message: message)
    }
    
    public func getPosition(flare: Flare) {
        let message = flare.flareInfo
        emit(event: "getPosition", message: message)
    }
    
    public func setPosition(flare: Flare, position: Point3D, sender: Flare?) {
        var message = flare.flareInfo
        if position.x.isNaN || position.y.isNaN || position.z.isNaN {
            NSLog("Invalid position: \(position)")
            return
        }
        message["position"] = position.toJSON() as AnyObject
        if sender != nil { message["sender"] = sender!.id as AnyObject }
        emit(event: "setPosition", message: message)
    }
    
    public func performAction(flare: Flare, action: String, sender: Flare?) {
        var message = flare.flareInfo
        message["action"] = action as AnyObject
        if sender != nil { message["sender"] = sender!.id as AnyObject }
        emit(event: "performAction", message: message)
    }
    
    // MARK: SocketIO received
    
    public func addHandlers() {
        socket.on("data") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let flare = self.flareForMessage(message: message),
                let data = message["data"] as? JSONDictionary
            {
                if self.debugSocket { NSLog("data: \(message)") }
                for (key,value) in data {
                    flare.data[key] = value
                }
                
                var sender: Flare? = nil
                if let senderId = message["sender"] as? String {
                    sender = self.flareIndex[senderId]
                }
                
                self.delegate?.didReceiveData(flare: flare, data: data, sender: sender)
            }
        }
        
        socket.on("position") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let flare = self.flareForMessage(message: message),
                let positionDict = message["position"] as? JSONDictionary
            {
                if self.debugSocket { NSLog("position: \(message)") }
                let newPosition = getPoint3D(json: positionDict);
                var oldPosition = Point3DZero
                
                if let thing = flare as? Thing {
                    oldPosition = thing.position
                    thing.position = newPosition
                } else if let device = flare as? Device {
                    oldPosition = device.position
                    device.position = newPosition
                }
                
                var sender: Flare? = nil
                if let senderId = message["sender"] as? String {
                    sender = self.flareIndex[senderId]
                }
                
                self.delegate?.didReceivePosition(flare: flare, oldPosition: oldPosition, newPosition: newPosition, sender: sender)
            }
        }
        
        socket.on("handleAction") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let flare = self.flareForMessage(message: message),
                let action = message["action"] as? String
            {
                if self.debugSocket { NSLog("handleAction: \(message)") }

                var sender: Flare? = nil
                if let senderId = message["sender"] as? String {
                    sender = self.flareIndex[senderId]
                }
                
                self.delegate?.handleAction(flare: flare, action: action, sender: sender)
            }
        }
        
        socket.on("enter") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let zoneId = message["zone"] as? String,
                let deviceId = message["device"] as? String,
                let zone = self.flareIndex[zoneId] as? Zone,
                let device = self.flareIndex[deviceId] as? Device
            {
                if self.debugSocket { NSLog("enter: \(message)") }
                self.delegate?.enter(zone: zone, device: device)
            }
        }
        
        socket.on("exit") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let zoneId = message["zone"] as? String,
                let deviceId = message["device"] as? String,
                let zone = self.flareIndex[zoneId] as? Zone,
                let device = self.flareIndex[deviceId] as? Device
            {
                if self.debugSocket { NSLog("exit: \(message)") }
                self.delegate?.exit(zone: zone, device: device)
            }
        }
        
        socket.on("near") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let thingId = message["thing"] as? String,
                let deviceId = message["device"] as? String,
                let thing = self.flareIndex[thingId] as? Thing,
                let device = self.flareIndex[deviceId] as? Device,
                let distance = message["distance"] as? Double
            {
                if self.debugSocket { NSLog("near: \(message)") }
                self.delegate?.near(thing: thing, device: device, distance: distance)
            }
        }
        
        socket.on("far") {messages, ack in
            if let message = messages[0] as? JSONDictionary,
                let thingId = message["thing"] as? String,
                let deviceId = message["device"] as? String,
                let thing = self.flareIndex[thingId] as? Thing,
                let device = self.flareIndex[deviceId] as? Device
            {
                if self.debugSocket { NSLog("far: \(message)") }
                self.delegate?.far(thing: thing, device: device)
            }
        }
    }
    
}
