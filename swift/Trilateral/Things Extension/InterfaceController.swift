//
//  InterfaceController.swift
//  Things Extension
//
//  Created by Andrew Zamler-Carhart on 2/7/16.
//  Copyright © 2016 Cisco. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }

    @IBOutlet weak var thingsTable: WKInterfaceTable!

    var things = [Thing]()
    var currentPosition = CGPoint(x: 0, y: 0)
    let numberFormatter = NumberFormatter()
    var defaults = UserDefaults.standard
    var session: WCSession?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.maximumFractionDigits = 0
        
        if WCSession.isSupported() {
            session = WCSession.default
            session!.delegate = self
            session!.activate()
        }
        
        for i in 1...3 {
            var thingInfo = JSONDictionary()
            thingInfo["name"] = "Thing \(i)" as AnyObject
            thingInfo["description"] = "Stuff \(i)" as AnyObject
            thingInfo["data"] = ["price":i * 10] as AnyObject
            thingInfo["position"] = ["x":i, "y":0] as AnyObject
            NSLog("Thing: \(thingInfo)")
            things.append(Thing(json: thingInfo))
        }
        
        delay(duration: 1.0) {
            NSLog("Getting things...")
            self.getThings()
            self.getPosition()
        }

        reloadTable()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func reloadTable() {
        if thingsTable.numberOfRows != things.count || things.count == 0 {
            thingsTable.setNumberOfRows(things.count, withRowType: "ThingRow")
        }
        
        // set the distance to each flare object from the current position
        for (_, flare) in things.enumerated() {
            flare.setDistanceFrom(currentPosition: currentPosition)
        }
        
        // sort the flare objects by distance
        things.sort { (one: Flare, two: Flare) -> Bool in
            return Unicode.CanonicalCombiningClass(rawValue: Unicode.CanonicalCombiningClass.RawValue(one.distance!)) < Unicode.CanonicalCombiningClass(rawValue: Unicode.CanonicalCombiningClass.RawValue(two.distance!))
        }
        
        // update the name and distance of the table rows
        for (index, flare) in things.enumerated() {
            if let row = thingsTable.rowController(at: index) as? TableRow {
                row.nameLabel.setText(flare.name)
                row.commentsLabel.setText(flare.comment)
                row.distanceLabel.setText(String(format:"%.1f", distanceString(flare: flare)))
                if let price = flare.data["price"] as? Int {
                    row.priceLabel.setText("$\(price)")
                }
            }
        }
    }
    
    // returns a human readable string that represents the distance to the flare object
    func distanceString(flare: Flare) -> String {
        if let distance = flare.distance {
            return "\(distance)"
        } else {
            return ""
        }
    }
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
            if segueIdentifier == "ShowDetails" {
                return things[rowIndex]
            }
            
            return nil
    }

    func getThings() {
        session!.sendMessage(["get":"things"],
                             replyHandler: ({ (message: [String : AnyObject]) -> Void in
                                self.gotThings(message: message)
                                } as! ([String : Any]) -> Void),
            errorHandler: ({ (error: NSError) -> Void in
                NSLog("Couldn't get things: \(error)")
                } as! (Error) -> Void))
    }
    
    func gotThings(message: JSONDictionary) {
        self.things = Thing.loadJson(json: message)
        NSLog("Got \(self.things.count) things.")
        
        if (self.things.count > 0) {
            self.getPosition()
            self.reloadTable()
        }
    }
    
    // initializes the location from the defaults,
    // sends a message to the iPhone to ask for the location
    // and then sets the location (if it receives a reply)
    func getPosition() {
        let x = defaults.double(forKey: "x")
        let y = defaults.double(forKey: "y")
        if (x != 0.0) && (y != 0.0) {
            currentPosition = CGPoint(x:x, y:y)
        }
        
        if (session != nil) {
            session!.sendMessage(["get":"position"],
                                 replyHandler: ({ (message: [String : AnyObject]) -> Void in
                                    self.setPosition(position: message)
                                    } as! ([String : Any]) -> Void),
                                 errorHandler: ({ (error: NSError) -> Void in
                                    NSLog("Couldn't get location: \(error)")
                                    } as! (Error) -> Void))
        }
    }
    
    // parses the location message, saves the values to the defaults,
    // sets the location and reloads the table
    func setPosition(position: JSONDictionary) {
        if let x = position["x"] as? Double,
            let y = position["y"] as? Double
        {
            defaults.set(x, forKey: "x")
            defaults.set(y, forKey: "y")
            
            currentPosition = CGPoint(x:x, y:y)
            reloadTable()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        NSLog("Got message: \(message)")
        
        if let position = message["position"] as? JSONDictionary {
            setPosition(position: position)
        } else if let _ = message["things"] as? JSONArray {
            gotThings(message: message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any],
                 replyHandler replyhandler: @escaping ([String : Any]) -> Void) {
            NSLog("Got message (reply handler): \(message)")
            
            if let position = message["position"] as? JSONDictionary {
                setPosition(position: position)
            } else if let _ = message["things"] as? JSONArray {
                gotThings(message: message)
            }
    }

}
