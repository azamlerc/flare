//
//  CompassViewController.swift
//  Trilateral
//
//  Created by Andrew Zamler-Carhart on 12/9/15.
//  Copyright © 2015 Cisco. All rights reserved.
//

import UIKit
import Flare
import CoreLocation

class CompassViewController: UIViewController {
    
    @IBOutlet weak var compass: CompassView!

    var appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidAppear(_ animated: Bool) {
        appDelegate.flareController = compass
        appDelegate.updateFlareController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}
