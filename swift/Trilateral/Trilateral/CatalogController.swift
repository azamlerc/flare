//
//  NearbyThingController.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 12/9/15.
//  Copyright © 2015 Cisco. All rights reserved.
//

import UIKit
import Flare

class CatalogController: UITableViewController, FlareController {
    
    var appDelegate = UIApplication.shared.delegate as! AppDelegate
    let thingCellIdentifier = "ThingCell"
    
    var currentEnvironment: Environment? { didSet(value) {
        self.tableView.reloadData()
        }}
    var currentZone: Zone?
    var device: Device?
    var nearbyThing: Thing? { didSet(value) {
            // update selection
            dataChanged()
        }}
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        appDelegate.flareController = self
        appDelegate.updateFlareController()
        
        dataChanged()
    }
    
    override func numberOfSections(in: UITableView) -> Int {
        if currentEnvironment == nil { return 0 }
        return currentEnvironment!.zones.count
    }
    
    override func tableView(_ : UITableView, titleForHeaderInSection: Int) -> String? {
        if currentEnvironment == nil { return "" }
        return currentEnvironment!.zones[titleForHeaderInSection].name
    }
    
    override func tableView(_: UITableView, numberOfRowsInSection: Int) -> Int {
        return currentEnvironment!.zones[numberOfRowsInSection].things.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: thingCellIdentifier) as! ThingCell
        cell.device = device
        cell.thing = currentEnvironment!.zones[indexPath.section].things[indexPath.row]
        return cell
    }
    
    override func tableView(_: UITableView, didSelectRowAt: IndexPath) {
        if currentEnvironment != nil {
            let thing = currentEnvironment!.zones[didSelectRowAt.section].things[didSelectRowAt.row]
            appDelegate.nearbyThing = thing
        }
    }
    
    func dataChanged() {
        if currentEnvironment != nil {
            for zone in currentEnvironment!.zones {
                zone.things.sort {
                    return device!.distanceTo(thing: $0) < device!.distanceTo(thing: $1)
                }
            }

            self.tableView.reloadData()
            
            for (section, zone) in currentEnvironment!.zones.enumerated() {
                for (row, thing) in zone.things.enumerated() {
                    if thing == nearbyThing {
                        self.tableView.selectRow(at: NSIndexPath(row: row, section: section) as IndexPath, animated: false, scrollPosition: .none)
                    }
                }
            }
        }
    }
    
    func animate() {
        // self.tableView.reloadData()
    }
}
