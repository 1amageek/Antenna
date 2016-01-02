//
//  MasterViewController.swift
//  Antenna
//
//  Created by 1amageek on 2016/01/01.
//  Copyright © 2016年 Stamp inc. All rights reserved.
//

import UIKit
import CoreBluetooth

class MasterViewController: UITableViewController, AntennaDelegate {

    var detailViewController: DetailViewController? = nil
    let serviceUUID = CBUUID(string: "CB0CC42D-8F20-4FA7-A224-DBC1707CF89A")
    
    deinit {
        Antenna.sharedAntenna.stopAdvertising()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Antenna.sharedAntenna.startAndReady({ () -> Void in
            Antenna.sharedAntenna.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[self.serviceUUID]])
            }, centralIsReadyHandler: { () -> Void in
                Antenna.sharedAntenna.scanForPeripheralsWithServices([self.serviceUUID])
        })
        Antenna.sharedAntenna.delegate = self
        
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {

        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Antenna.sharedAntenna.connectedPeripherals.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        let object = Antenna.sharedAntenna.connectedPeripherals![indexPath.row]
        cell.textLabel!.text = object.description
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    func antenna(antenna: Antenna, didChangeConnectedPeripherals peripherals: [CBPeripheral]) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.tableView.reloadData()
        }
    }

}

