//
//  AppDelegate.swift
//  Flare Test
//
//  Created by Andrew Zamler-Carhart on 3/23/15.
//  Copyright (c) 2015 Andrew Zamler-Carhart. All rights reserved.
//

import Cocoa
import Flare

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, FlareManagerDelegate, NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var mapWindow: NSWindow!
    @IBOutlet weak var compassWindow: NSWindow!
    @IBOutlet weak var logWindow: NSWindow!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var map: IndoorMap!
    @IBOutlet weak var compass: CompassView!
    @IBOutlet weak var logTable: NSTableView!
    
    @IBOutlet weak var idField: NSTextField!
    @IBOutlet weak var nameField: NSTextField!
    @IBOutlet weak var commentField: NSTextField!
    @IBOutlet weak var actionsField: NSTokenField!
    @IBOutlet weak var optionsField: NSTokenField!

    @IBOutlet weak var uuidField: NSTextField!
    @IBOutlet weak var environmentXField: NSTextField!
    @IBOutlet weak var environmentYField: NSTextField!
    @IBOutlet weak var environmentZField: NSTextField!
    @IBOutlet weak var environmentWidthField: NSTextField!
    @IBOutlet weak var environmentHeightField: NSTextField!
    @IBOutlet weak var environmentDepthField: NSTextField!
    @IBOutlet weak var environmentAngleField: NSTextField!
    @IBOutlet weak var environmentDistanceField: NSTextField!
    @IBOutlet weak var latitudeField: NSTextField!
    @IBOutlet weak var longitudeField: NSTextField!
    @IBOutlet weak var radiusField: NSTextField!
    @IBOutlet weak var flippedCheckbox: NSButton!
    
    @IBOutlet weak var majorField: NSTextField!
    @IBOutlet weak var zoneXField: NSTextField!
    @IBOutlet weak var zoneYField: NSTextField!
    @IBOutlet weak var zoneZField: NSTextField!
    @IBOutlet weak var zoneWidthField: NSTextField!
    @IBOutlet weak var zoneHeightField: NSTextField!
    @IBOutlet weak var zoneDepthField: NSTextField!

    @IBOutlet weak var minorField: NSTextField!
    @IBOutlet weak var colorField: NSTextField!
    @IBOutlet weak var brightnessField: NSTextField!
    @IBOutlet weak var thingXField: NSTextField!
    @IBOutlet weak var thingYField: NSTextField!
    @IBOutlet weak var thingZField: NSTextField!

    @IBOutlet weak var macField: NSTextField!
    @IBOutlet weak var angleField: NSTextField!
    @IBOutlet weak var deviceXField: NSTextField!
    @IBOutlet weak var deviceYField: NSTextField!
    @IBOutlet weak var deviceZField: NSTextField!

    @IBOutlet weak var nearbyDeviceView: NSView!
    @IBOutlet weak var nearbyDeviceIdField: NSTextField!
    @IBOutlet weak var nearbyDeviceNameField: NSTextField!
    @IBOutlet weak var nearbyDeviceCommentField: NSTextField!
    @IBOutlet weak var nearbyDeviceDistanceField: NSTextField!
    @IBOutlet weak var nearbyDeviceAngleField: NSTextField!
    
    @IBOutlet weak var nearbyThingView: NSView!
    @IBOutlet weak var nearbyThingIdField: NSTextField!
    @IBOutlet weak var nearbyThingNameField: NSTextField!
    @IBOutlet weak var nearbyThingCommentField: NSTextField!
    @IBOutlet weak var nearbyThingDistanceField: NSTextField!
    @IBOutlet weak var nearbyThingColorField: NSTextField!
    @IBOutlet weak var nearbyThingBrightnessField: NSTextField!
    
    @IBOutlet weak var mapDirectionButtons: NSView!
    @IBOutlet weak var compassDirectionButtons: NSView!

    @IBOutlet weak var dataPanel: NSPanel!
    @IBOutlet weak var dataScroll: NSScrollView!
    var dataText: NSTextView { get { return dataScroll.contentView.documentView as! NSTextView }}

    
    var flareManager = FlareManager(host: "localhost", port: 1234)
    var environments = [Environment]()
    var selectedFlare, nearbyFlare: Flare?
    var logEvents = JSONArray()
    var defaults: UserDefaults
    
    let animationDelay = 0.5
    let animationSteps = 30
    
    override init() {
        defaults = UserDefaults.standard
        
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let path = Bundle.main.path(forResource: "Defaults", ofType: "plist")
        let factorySettings = NSDictionary(contentsOfFile: path!)
        let defaultsController = NSUserDefaultsController.shared
        
        defaults.register(defaults: factorySettings! as! [String : AnyObject])

        defaultsController.addObserver(self, forKeyPath: "values.host", options: [], context: nil)
        defaultsController.addObserver(self, forKeyPath: "values.port", options: [], context: nil)
        
        dataText.isAutomaticQuoteSubstitutionEnabled = false
        dataText.isAutomaticDashSubstitutionEnabled = false
        dataText.isAutomaticTextReplacementEnabled = false
        
        load()
    }
    
    func load() {
        let host = defaults.string(forKey: "host")!
        let port = defaults.integer(forKey: "port")
        
        print("host: \(host)")
        print("port: \(port)")
        
        flareManager = FlareManager(host: host, port: port)
        flareManager.delegate = self
        flareManager.debugHttp = true
        flareManager.debugSocket = false
        
        NSLog("Flare server: \(flareManager.server)")
        
        flareManager.connect()
        
        let selected = defaults.string(forKey: "selectedId")
        loadEnvironments(selectId: selected)
    }

    @IBAction func refresh(_ sender: AnyObject) {
        let selected = defaults.string(forKey: "selectedId")
        loadEnvironments(selectId: selected)
    }
    
    func loadEnvironments(selectId: String?) {
        flareManager.loadEnvironments() {(environments)->() in
            self.environments = environments
            self.printEnvironments()
            self.outlineView.reloadData()
            self.expandAll()
            
            if selectId != nil {
                if let newSelected = self.flareManager.flareIndex[selectId!] {
                    let row = self.outlineView.row(forItem: newSelected)
                    if row != NSNotFound {
                        self.outlineView.selectRowIndexes(NSIndexSet(index: row) as IndexSet, byExtendingSelection: false)
                        self.outlineView.scrollRowToVisible(row)
                    }
                }
            }
            
            if self.defaults.bool(forKey: "logAll") { // subscribe to changes to all Flare objects
                for environment in environments {
                    self.flareManager.subscribe(flare: environment, all: true)
                }
            }
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?)
    {
        switch keyPath! {
            case "values.host", "values.port": load()
            default: break
        }
    }

    @IBAction func resubscribe(_ sender: AnyObject) {
        if defaults.bool(forKey: "logAll") {
            if selectedFlare != nil {
                NSLog("unsubscribe: \(selectedFlare!.name)")
                flareManager.unsubscribe(flare: selectedFlare!)
            }
            
            for environment in self.environments {
                NSLog("subscribe: \(environment.name)")
                flareManager.subscribe(flare: environment, all: true)
            }
        } else {
            for environment in self.environments {
                NSLog("unsubscribe: \(environment.name)")
                flareManager.unsubscribe(flare: environment)
            }

            if selectedFlare != nil {
                NSLog("subscribe: \(selectedFlare!.name)")
                flareManager.subscribe(flare: selectedFlare!, all: true)
            }
        }
    }
    
    func printEnvironments() {
        print("Environments:")
        for environment in environments {
            print("\(environment)")
            
            for zone in environment.zones {
                print("  \(zone)")
                
                for thing in zone.things {
                    print("    \(thing)")
                }
            }
            
            if environment.devices.count > 0 {
                print("  Devices")
                for device in environment.devices {
                    print("    \(device)")
                }
            }
        }
    }
    
    func expandAll() {
        for environment in environments {
            outlineView.expandItem(environment)
            
            for zone in environment.zones {
                outlineView.expandItem(zone)
            }
        }
    }
    
    @IBAction func addRemove(_ sender: NSSegmentedControl) {
        let selected = sender.selectedSegment

        switch selected {
        case 0: newFlare(sender)
        case 1: deleteFlare(sender)
        default: break
        }
    }
    
    @IBAction func newFlare(_ sender: AnyObject) {
        let template: JSONDictionary = ["name":"Untitled", "description":"", "data":[:]]

        flareManager.newFlare(flare: selectedFlare, json: template) { json in
            if let selectId = json["_id"] as? String {
                self.loadEnvironments(selectId: selectId)
            }
        }
    }
    
    @IBAction func deleteFlare(_ sender: AnyObject) {
        if let flare = selectedFlare {
            let alert = NSAlert()
            alert.messageText = "Do you want to delete “\(flare.name)”?"
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            alert.informativeText = "This operation cannot be undone."
            
            alert.beginSheetModal(for: self.window, completionHandler: { (returnCode) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    let parentId = flare.parentId()
                    self.flareManager.deleteFlare(flare: flare) { json in
                        self.loadEnvironments(selectId: parentId)
                    }
                }
            })
        }

        
    }
    
    @IBAction func importData(_ sender: AnyObject) {
        let panel = NSOpenPanel()
        panel.beginSheetModal(for: window) { result in
            if result.rawValue == NSFileHandlingPanelOKButton {
                if let url = panel.url {
                    NSLog("Open: \(url)")
                    if let data = NSData(contentsOf: url) {
                        if let json = try? JSONSerialization.jsonObject(with: data as Data, options: []) as? JSONDictionary,
                            let jsonArray = json["environments"] as? JSONArray
                        {
                            NSLog("Objects: \(jsonArray)")
                            self.importEnvironments(jsonArray: jsonArray)
                        }
                    }
                }
            }
        }
    }

    @IBAction func exportData(_ sender: AnyObject) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.beginSheetModal(for: window) { result in
            if result.rawValue == NSFileHandlingPanelOKButton {
                if let url = panel.url {
                    NSLog("Save: \(url)")
                    let json = ["environments": self.environments.map({$0.toJSON()})]
                    if let data = try? JSONSerialization.data(withJSONObject: json, options: []) {
                        do {
                            try data.write(to: url)
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        }
    }
    
    var requests = 0

    func startRequest() {
        requests += 1
    }
    
    func finishRequest() {
        requests -= 1
        if requests == 0 {
            self.refresh(self)
        }
    }
    
    // merge the imported files
    func importEnvironments(jsonArray: JSONArray) {
        for environmentJson in jsonArray {
            self.startRequest()
            self.flareManager.newOrUpdateEnvironment(environment: environmentJson) { newEnvironment in
                if let environmentId = newEnvironment["_id"] as? String {
                    if let zones = environmentJson["zones"] as? JSONArray {
                        for zoneJson in zones {
                            self.startRequest()
                            self.flareManager.newOrUpdateZone(zone: zoneJson, environmentId: environmentId) { newZone in
                                if let zoneId = newZone["_id"] as? String {
                                    if let things = zoneJson["things"] as? JSONArray {
                                        for thingJson in things {
                                            self.startRequest()
                                            self.flareManager.newOrUpdateThing(thing: thingJson, environmentId: environmentId, zoneId: zoneId) { _ in
                                                self.finishRequest()
                                            }
                                        }
                                    }
                                }
                                self.finishRequest()
                            }
                        }
                    }
                    if let devices = environmentJson["devices"] as? JSONArray {
                        for deviceJson in devices {
                            self.startRequest()
                            self.flareManager.newOrUpdateDevice(device: deviceJson, environmentId: environmentId) { _ in
                                self.finishRequest()
                            }
                        }
                    }
                }
                self.finishRequest()
            }
        }
    }
    
    // MARK: Callbacks
    
    func didReceiveData(flare: Flare, data: JSONDictionary, sender: Flare?) {
        NSLog("\(flare.name) data: \(data)")
        if data.keys.count == 1 {
            if let key = data.keys.first, let value = data[key] {
                if key != "angle" || defaults.bool(forKey: "logDetailed") { // only log angle if logDetailed == true
                    addLogEvent(name: "data", flare1: flare, flare2: sender, key: key, value: value as AnyObject)
                }
            }
        } else {
            if let dataString = data.toJSONString() {
                addLogEvent(name: "data", flare1: flare, flare2: sender, key: "data", value: dataString as AnyObject)
            }
        }
        
        if flare == selectedFlare {
            if let color = data["color"] as? String {
                colorField.stringValue = color
            }
            
            if let brightness = data["brightness"] as? Double {
                brightnessField.doubleValue = brightness
            }

            if let angle = data["angle"] as? Double {
                angleField.doubleValue = angle
            }

            if let mac = data["mac"] as? String {
                macField.stringValue = mac
            }
            
        } else if flare == nearbyFlare {
            if let angle = data["angle"] as? Double {
                nearbyDeviceAngleField.doubleValue = angle
            }

            if let color = data["color"] as? String {
                nearbyThingColorField.stringValue = color
            }

            if let brightness = data["brightness"] as? Double {
                nearbyThingBrightnessField.doubleValue = brightness
            }
        }
        
        map.dataChanged()
        compass.dataChanged()
    }
    
    func didReceivePosition(flare: Flare, oldPosition: Point3D, newPosition: Point3D, sender: Flare?) {
        // NSLog("\(flare.name) position: \(newPosition)")
        if defaults.bool(forKey: "logDetailed") {
            addLogEvent(name: "position", flare1: flare, flare2: sender, key: "position", value: "\(newPosition.x),\(newPosition.y),\(newPosition.z)" as AnyObject)
        }
        
        if flare == selectedFlare {
            if flare is Thing {
                thingXField.doubleValue = Double(newPosition.x)
                thingYField.doubleValue = Double(newPosition.y)
                thingZField.doubleValue = Double(newPosition.z)
            } else if flare is Device {
                deviceXField.doubleValue = Double(newPosition.x)
                deviceYField.doubleValue = Double(newPosition.y)
                deviceZField.doubleValue = Double(newPosition.z)
            }
        } else if flare == nearbyFlare {
            if let device = nearbyFlare as? Device, let thing = selectedFlare as? Thing {
                let distance = device.position - thing.position
                nearbyDeviceDistanceField.doubleValue = distance
            } else if let thing = nearbyFlare as? Thing, let device = selectedFlare as? Device {
                let distance = thing.position - device.position
                nearbyThingDistanceField.doubleValue = distance
            }
        }

        animateFlare(flare: flare as! FlarePosition, oldPosition: oldPosition, newPosition: newPosition)
    }
    
    func handleAction(flare: Flare, action: String, sender: Flare?) {
        NSLog("\(flare.name) action: \(action)")
        addLogEvent(name: "action", flare1: flare, flare2: sender, key: "action", value: action as AnyObject)
    }
    
    func enter(zone: Zone, device: Device) {
        NSLog("\(zone.name) enter: \(device.name)")
        addLogEvent(name: "enter", flare1: device, flare2: zone)
    }
    
    func exit(zone: Zone, device: Device) {
        NSLog("\(zone.name) exit: \(device.name)")
        addLogEvent(name: "exit", flare1: device, flare2: zone)
    }
    
    func near(thing: Thing, device: Device, distance: Double) {
        NSLog("\(thing.name) near: \(device.name) (\(distance))")
        addLogEvent(name: "near", flare1: device, flare2: thing, key: "distance", value: distance as AnyObject)
        
        if selectedFlare == thing && nearbyFlare != device {
            nearbyFlare = device
            
            if !defaults.bool(forKey: "logAll") { flareManager.subscribe(flare: device) }
            flareManager.getData(flare: device)
            flareManager.getPosition(flare: device)
            
            nearbyDeviceIdField.stringValue = device.id
            nearbyDeviceNameField.stringValue = device.name
            nearbyDeviceCommentField.stringValue = device.comment
            nearbyDeviceDistanceField.doubleValue = distance
            if let angle = device.data["angle"] as? Double {
                nearbyDeviceAngleField.doubleValue = angle
            }
            
            nearbyDeviceView.isHidden = false
        } else if selectedFlare == device && nearbyFlare != thing {
            nearbyFlare = thing
            map.nearbyThing = thing
            compass.nearbyThing = thing
            
            if !defaults.bool(forKey: "logAll") { flareManager.subscribe(flare: thing) }
            flareManager.getData(flare: thing)
            flareManager.getPosition(flare: thing)

            nearbyThingIdField.stringValue = thing.id
            nearbyThingNameField.stringValue = thing.name
            nearbyThingCommentField.stringValue = thing.comment
            nearbyThingDistanceField.doubleValue = distance
            if let color = thing.data["color"] as? String {
                nearbyThingColorField.stringValue = color
            }
            if let brightness = thing.data["brightness"] as? Double {
                nearbyThingBrightnessField.doubleValue = brightness
            }
            
            nearbyThingView.isHidden = false
}
    }
    
    func far(thing: Thing, device: Device) {
        // NSLog("\(device.name) far: \(thing.name)")
        addLogEvent(name: "far", flare1: device, flare2: thing)
        
        if selectedFlare == thing && nearbyFlare == device {
            nearbyDeviceView.isHidden = true
            
            if !defaults.bool(forKey: "logAll") { flareManager.unsubscribe(flare: device) }
            
            nearbyFlare = nil
        } else if selectedFlare == device && nearbyFlare == thing {
            nearbyThingView.isHidden = true
            
            if !defaults.bool(forKey: "logAll") { flareManager.unsubscribe(flare: thing) }
            
            nearbyFlare = nil
            map.nearbyThing = nil
            compass.nearbyThing = nil
        }
    }
    
    func addLogEvent(name: String, flare1: Flare, flare2: Flare?) {
        addLogEvent(name: name, flare1: flare1, flare2: flare2, key: nil, value: nil)
    }
    
    func addLogEvent(name: String, flare1: Flare, flare2: Flare?, key: String?, value: AnyObject?) {
        var event: JSONDictionary = ["time": NSDate()]
        
        event["event"] = name
        event["type"] = flare1.flareClass
        event["id"] = flare1.id
        event["name"] = flare1.name
        
        if flare2 != nil {
            event["type2"] = flare2!.flareClass
            event["id2"] = flare2!.id
            event["name2"] = flare2!.name
        }
        
        if key != nil { event["key"] = key! }
        if value != nil { event["value"] = value! }
        
        logEvents.append(event)
        logTable.reloadData()
        logTable.scrollToEndOfDocument(self)
    }
    
    // MARK: Actions
    
    @IBAction func changeName(_ sender: NSTextField) {
        if let flare = selectedFlare {
            let name = sender.stringValue
            flare.name = name
            self.outlineView.reloadData()
            flareManager.updateFlare(flare: flare, json: ["name":name]) {json in }
        }
    }
    
    @IBAction func changeComment(_ sender: NSTextField) {
        if let flare = selectedFlare {
            let comment = sender.stringValue
            flare.comment = comment
            flareManager.updateFlare(flare: flare, json: ["description":comment]) {json in }
        }
    }
    
    @IBAction func changeActions(_ sender: NSTokenField) {
        if let flare = selectedFlare {
            if let actions = sender.objectValue as? [String] {
                flare.actions = actions
                flareManager.updateFlare(flare: flare, json: ["actions":actions]) {json in }
            }
        }
    }

    @IBAction func changeOptions(_ sender: NSTokenField) {
        if let flare = selectedFlare {
            NSLog("Options: \(sender.objectValue!)")
            
            if let options = sender.objectValue {
                flare.data["options"] = options
                flareManager.setData(flare: flare, key: "options", value: options as AnyObject, sender: nil)
            }
        }
    }
    
    // sender.identifier can contain several words
    // the first word is the key
    // if the words contains "nearby", sends the message for the nearby flare rather than the selected flare
    // if the words contains "integer" or "double", formats the value as a number
    @IBAction func changeData(_ sender: NSTextField) {
        let identifiers = sender.identifier!.rawValue.components(separatedBy: " ")
        let key = identifiers.first!
        let nearby = identifiers.contains("nearby")
        
        var value: AnyObject? = nil
        if identifiers.contains("integer") {
            value = sender.integerValue as AnyObject
        } else if identifiers.contains("double") {
            value = sender.doubleValue as AnyObject
        } else {
            value = sender.stringValue as AnyObject
        }
        
        if let flare = nearby ? nearbyFlare : selectedFlare {
            flare.data[key] = value!
            flareManager.setData(flare: flare, key: key, value: value!, sender: nil)
            addLogEvent(name: "data", flare1: flare, flare2: nil, key: key, value: value!)
            
            map.dataChanged()
            compass.dataChanged()
        }
    }
    
    @IBAction func changeState(_ sender: NSButton) {
        let identifiers = sender.identifier!.rawValue.components(separatedBy: " ")
        let key = identifiers.first!
        let nearby = identifiers.contains("nearby")
        let value = sender.state
        
        if let flare = nearby ? nearbyFlare : selectedFlare {
            flare.data[key] = value
            flareManager.setData(flare: flare, key: key, value: value.rawValue as AnyObject, sender: nil)
            addLogEvent(name: "data", flare1: flare, flare2: nil, key: key, value: value as AnyObject)
            
            map.dataChanged()
            compass.dataChanged()
        }
    }

    @IBAction func changePosition(_ sender: NSTextField) {
        if let thing = selectedFlare as? Thing {
            let newPosition = Point3D(x: thingXField.doubleValue, y: thingYField.doubleValue, z: thingZField.doubleValue)
            animateFlare(flare: thing, oldPosition: thing.position, newPosition: newPosition)
            flareManager.setPosition(flare: thing, position: newPosition, sender: nil)
            addLogEvent(name: "position", flare1: thing, flare2: nil, key: "position", value: "\(newPosition.x),\(newPosition.y),\(newPosition.z)" as AnyObject)
        } else if let device = selectedFlare as? Device {
            let newPosition = Point3D(x: deviceXField.doubleValue, y: deviceYField.doubleValue, z: deviceZField.doubleValue)
            animateFlare(flare: device, oldPosition: device.position, newPosition: newPosition)
            flareManager.setPosition(flare: device, position: newPosition, sender: nil)
            addLogEvent(name: "position", flare1: device, flare2: nil, key: "position", value: "\(newPosition.x),\(newPosition.y),\(newPosition.z)" as AnyObject)
        }
    }

    func animateFlare(flare: FlarePosition, oldPosition: Point3D, newPosition: Point3D) {
        var animatedFlare = flare
        let dx = (newPosition.x - oldPosition.x) / CGFloat(animationSteps)
        let dy = (newPosition.y - oldPosition.y) / CGFloat(animationSteps)
        let dz = (newPosition.z - oldPosition.z) / CGFloat(animationSteps)

        delayLoop(duration: animationDelay, steps: animationSteps) { i in
            animatedFlare.position = Point3D(x: oldPosition.x + CGFloat(i) * dx,
                                             y: oldPosition.y + CGFloat(i) * dy,
                                             z: oldPosition.z + CGFloat(i) * dz)
            self.map.dataChanged()
            self.compass.dataChanged()
        }
    }
    
    @IBAction func changeGeofence(_ sender: NSTextField) {
        if let environment = selectedFlare as? Environment {
            let geofence = ["latitude":latitudeField.doubleValue,
                            "longitude":longitudeField.doubleValue,
                            "radius":radiusField.doubleValue]
            environment.geofence = Geofence(json: geofence)
            flareManager.updateFlare(flare: environment, json: ["geofence":geofence]) {json in }
        }
    }
    
    @IBAction func changeEnvironmentAngle(_ sender: NSTextField) {
        if let environment = selectedFlare as? Environment {
            let angle = environmentAngleField.doubleValue
            environment.angle = angle
            flareManager.updateFlare(flare: environment, json: ["angle":angle]) {json in }
        }
    }
    
    @IBAction func changeEnvironmentPerimeter(_ sender: NSTextField) {
        if let environment = selectedFlare as? Environment {
            let perimeter = ["origin":["x":environmentXField.doubleValue, "y":environmentYField.doubleValue, "z":environmentZField.doubleValue],
                "size":["width":environmentWidthField.doubleValue, "height":environmentHeightField.doubleValue, "depth":environmentDepthField.doubleValue]]
            environment.perimeter = getCube3D(json: perimeter)
            map.dataChanged()
            flareManager.updateFlare(flare: environment, json: ["perimeter":perimeter]) {json in }
        }
    }
    
    @IBAction func changeZonePerimeter(_ sender: NSTextField) {
        if let zone = selectedFlare as? Zone {
            let perimeter = ["origin":["x":zoneXField.doubleValue, "y":zoneYField.doubleValue, "z":zoneZField.doubleValue],
                "size":["width":zoneWidthField.doubleValue, "height":zoneHeightField.doubleValue, "depth":zoneDepthField.doubleValue]]
            zone.perimeter = getCube3D(json: perimeter)
            map.dataChanged()
            flareManager.updateFlare(flare: zone, json: ["perimeter":perimeter]) {json in }
        }
    }
    
    // sender.identifier can contain several words
    // the first word is the action
    // if the words contains "nearby", sends the message for the nearby flare rather than the selected flare
    @IBAction func performAction(_ sender: NSButton) {
        let identifiers = sender.identifier!.rawValue.components(separatedBy: " ")
        let action = identifiers.first!
        let nearby = identifiers.contains("nearby")
        
        if let flare = nearby ? nearbyFlare : selectedFlare {
            flareManager.performAction(flare: flare, action: action, sender: nil)
            addLogEvent(name: "action", flare1: flare, flare2: nil, key: "action", value: action as AnyObject)
        }
    }
    
    // MARK: Outline View
    
    func reloadData() {
        outlineView.reloadData()
    }
    
    func reloadItem(item: Flare) {
        outlineView.reloadItem(item, reloadChildren: true)
        
        if item.children().count > 0 {
            outlineView.expandItem(item)
        } else {
            outlineView.collapseItem(item)
        }
    }
    
    func selectedItem() -> Flare? {
        if let flare = outlineView.item(atRow: outlineView.selectedRow) as? Flare { return flare }
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let environment = item as? Environment {
            return environment.zones.count + environment.devices.count
        } else {
            return item == nil ? environments.count : (item as! Flare).children().count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let environment = item as? Environment {
            let zoneCount = environment.zones.count
            return index < zoneCount ? environment.zones[index] : environment.devices[index - zoneCount]
        } else {
            return item == nil ? environments[index] : (item as! Flare).children()[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return !(item is Thing || item is Device)
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view = (item as! Flare).id == "" ?
            outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as! NSTableCellView :
            outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! NSTableCellView
        
        view.textField!.stringValue = (item as! Flare).name
        
        if item is Environment {
            view.imageView!.image = NSImage(named: "NSHomeTemplate")
        } else if item is Zone {
            view.imageView!.image = NSImage(named: "NSIChatTheaterTemplate")
        } else if item is Thing {
            view.imageView!.image = NSImage(named: "NSActionTemplate")
        } else if item is Device {
            view.imageView!.image = NSImage(named: "NSComputer")
        }
        
        return view
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        updateSelectedFlare()
    }
    
    func updateSelectedFlare() {
        if let oldFlare = selectedFlare {
            if !defaults.bool(forKey: "logAll") { flareManager.unsubscribe(flare: oldFlare) }
            
            idField.stringValue = ""
            nameField.stringValue = ""
            commentField.stringValue = ""
            optionsField.objectValue = []
            actionsField.objectValue = []
            uuidField.stringValue = ""
            environmentXField.stringValue = ""
            environmentYField.stringValue = ""
            environmentZField.stringValue = ""
            environmentWidthField.stringValue = ""
            environmentHeightField.stringValue = ""
            environmentDepthField.stringValue = ""
            environmentAngleField.stringValue = ""
            environmentDistanceField.stringValue = ""
            latitudeField.stringValue = ""
            longitudeField.stringValue = ""
            radiusField.stringValue = ""
            flippedCheckbox.state = NSControl.StateValue(rawValue: 0)
            majorField.stringValue = ""
            zoneXField.stringValue = ""
            zoneYField.stringValue = ""
            zoneZField.stringValue = ""
            zoneWidthField.stringValue = ""
            zoneHeightField.stringValue = ""
            zoneDepthField.stringValue = ""
            minorField.stringValue = ""
            colorField.stringValue = ""
            brightnessField.stringValue = ""
            thingXField.stringValue = ""
            thingYField.stringValue = ""
            thingZField.stringValue = ""
            macField.stringValue = ""
            angleField.stringValue = ""
            deviceXField.stringValue = ""
            deviceYField.stringValue = ""
            deviceZField.stringValue = ""
        }
        
        selectedFlare = selectedItem()
        map.selectedFlare = selectedFlare
        nearbyDeviceView.isHidden = true
        nearbyThingView.isHidden = true
        nearbyFlare = nil
        
        if let newFlare = selectedFlare {
            defaults.set(newFlare.id, forKey: "selectedId")
            
            if !defaults.bool(forKey: "logAll") { flareManager.subscribe(flare: newFlare, all: true) }
            flareManager.getData(flare: newFlare)
            
            idField.stringValue = newFlare.id
            nameField.stringValue = newFlare.name
            commentField.stringValue = newFlare.comment
            actionsField.objectValue = newFlare.actions
            optionsField.objectValue = newFlare.data["options"]

            if let environment = flareManager.environmentForFlare(flare: newFlare) {
                self.map.loadEnvironment(value: environment)

                if compass.device == nil {
                    NSLog("Devices: \(environment.devices)")
                    if let device = environment.devices.first {
                        compass.environment = environment
                        compass.device = device
                        compass.dataChanged()
                    }
                }
            }
            
            compass.selectedThing = nil
            
            if let environment = selectedFlare as? Environment {
                tabView.selectTabViewItem(at: 0)
                mapDirectionButtons.isHidden = true
                compassDirectionButtons.isHidden = true
                
                if let uuid = environment.data["uuid"] as? String { uuidField.stringValue = uuid }
                environmentXField.doubleValue = Double(environment.perimeter.origin.x)
                environmentYField.doubleValue = Double(environment.perimeter.origin.y)
                environmentZField.doubleValue = Double(environment.perimeter.origin.z)
                environmentWidthField.doubleValue = Double(environment.perimeter.size.width)
                environmentHeightField.doubleValue = Double(environment.perimeter.size.height)
                environmentDepthField.doubleValue = Double(environment.perimeter.size.depth)
                environmentAngleField.doubleValue = Double(environment.angle)
                latitudeField.doubleValue = Double(environment.geofence.latitude)
                longitudeField.doubleValue = Double(environment.geofence.longitude)
                radiusField.doubleValue = Double(environment.geofence.radius)
                if let flipped = environment.data["flipped"] as? Int { flippedCheckbox.state = NSControl.StateValue(rawValue: flipped) }
                if let distance = environment.data["distance"] as? Double { environmentDistanceField.doubleValue = distance }
            } else if let zone = selectedFlare as? Zone {
                NSLog("Selected \(zone)")
                tabView.selectTabViewItem(at: 1)
                mapDirectionButtons.isHidden = true
                compassDirectionButtons.isHidden = true
                
                if let major = zone.data["major"] as? Int { majorField.integerValue = major }
                
                zoneXField.doubleValue = Double(zone.perimeter.origin.x)
                zoneYField.doubleValue = Double(zone.perimeter.origin.y)
                zoneZField.doubleValue = Double(zone.perimeter.origin.z)
                zoneWidthField.doubleValue = Double(zone.perimeter.size.width)
                zoneHeightField.doubleValue = Double(zone.perimeter.size.height)
                zoneDepthField.doubleValue = Double(zone.perimeter.size.depth)
            } else if let thing = selectedFlare as? Thing {
                NSLog("Selected \(thing)")
                tabView.selectTabViewItem(at: 2)
                mapDirectionButtons.isHidden = false
                compassDirectionButtons.isHidden = false

                if let minor = thing.data["minor"] as? Int { minorField.integerValue = minor }

                flareManager.getPosition(flare: thing)
                
                if let color = thing.data["color"] as? String { colorField.stringValue = color }
                if let brightness = thing.data["brightness"] as? Double { brightnessField.doubleValue = brightness }
                
                thingXField.doubleValue = Double(thing.position.x)
                thingYField.doubleValue = Double(thing.position.y)
                thingZField.doubleValue = Double(thing.position.z)
                
                compass.selectedThing = thing
                compass.dataChanged()
            } else if let device = selectedFlare as? Device {
                NSLog("Selected \(device)")
                defaults.set(newFlare.id, forKey: "selectedDeviceId")
                tabView.selectTabViewItem(at: 3)
                mapDirectionButtons.isHidden = false
                compassDirectionButtons.isHidden = false

                if let angle = device.data["angle"] as? String { angleField.stringValue = angle }
                if let mac = device.data["mac"] as? String { macField.stringValue = mac }
                deviceXField.doubleValue = Double(device.position.x)
                deviceYField.doubleValue = Double(device.position.y)
                deviceZField.doubleValue = Double(device.position.z)
                
                if let environment = flareManager.environmentForFlare(flare: device) {
                    compass.environment = environment
                    compass.device = device
                    compass.dataChanged()
                }
            }
        }
        
        map.dataChanged()
    }
    
    // MARK: Data
    
    @IBAction func showData(_ sender: AnyObject) {
        if selectedFlare != nil {
            flareManager.getFlare(flare: selectedFlare!) { json in
                if let currentData = json["data"] as? JSONDictionary, let dataString = currentData.toJSONString() {
                    self.selectedFlare!.data = currentData // save the current value
                    self.dataText.textStorage!.mutableString.setString(dataString)
                    self.window.beginSheet(self.dataPanel) { returnCode in
                        if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                            let newString = self.dataText.textStorage!.mutableString
                            if let newData = ((newString as String).data(using: .utf8)! as NSData).toJSONDictionary() {
                                if newData == self.selectedFlare!.data {
                                    NSLog("Data is the same")
                                } else {
                                    self.selectedFlare!.data = newData
                                    self.flareManager.updateFlare(flare: self.selectedFlare!, json: ["data":newData]) { newJson in
                                        NSLog("Updated data: \(newJson)")
                                        self.updateSelectedFlare()
                                    }
                                }
                            } else {
                                let alert = NSAlert()
                                alert.messageText = "Sorry, but this JSON is invalid:"
                                alert.addButton(withTitle: "OK")
                                alert.informativeText = newString as String
                                alert.beginSheetModal(for: self.window) {response in }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func dataOK(_ sender: AnyObject) {
        window.endSheet(dataPanel, returnCode: NSApplication.ModalResponse.alertFirstButtonReturn)
    }
    
    @IBAction func dataCancel(_ sender: AnyObject) {
        window.endSheet(dataPanel, returnCode: NSApplication.ModalResponse.alertSecondButtonReturn)
    }
    
    // MARK: Tables
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == logTable {
            return logEvents.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == logTable {
            return logEvents[row][tableColumn!.identifier.rawValue] as AnyObject?
        }
        
        return nil
    }
}
