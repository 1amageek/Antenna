//
//  MasterViewController.swift
//  Antenna
//
//  Created by 1amageek on 2016/01/01.
//  Copyright © 2016年 Stamp inc. All rights reserved.
//

import UIKit
import CoreBluetooth
import Photos

class MasterViewController: UITableViewController, AntennaDelegate {

    var detailViewController: DetailViewController? = nil
    let characteristicUUID: CBUUID = CBUUID(string: "3E770C8F-DB75-43AA-A335-1013A728BF42")
    let serviceUUID = CBUUID(string: "CB0CC42D-8F20-4FA7-A224-DBC1707CF89A")
    
    var peripheralManager: CBPeripheralManager!
    
    
    deinit {
        Antenna.sharedAntenna.stopAdvertising()
    }

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Antenna.sharedAntenna.delegate = self
        Antenna.sharedAntenna.startAndReady { (antenna) -> Void in
            let characteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: self.characteristicUUID, properties: CBCharacteristicProperties.Notify, value: nil, permissions: .Readable)
            let service: CBMutableService = CBMutableService(type: self.serviceUUID, primary: true)
            service.characteristics = [characteristic]
            antenna.services = [service]

            antenna.startAdvertising([CBAdvertisementDataLocalNameKey: "Antenna", CBAdvertisementDataServiceUUIDsKey: [self.serviceUUID]])
            //antenna.stopAdvertising()
            antenna.scanForPeripheralsWithServices([self.serviceUUID])
            
        }
        
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

