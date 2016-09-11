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

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    let characteristicUUID: CBUUID = CBUUID(string: "3E770C8F-DB75-43AA-A335-1013A728BF42")
    let serviceUUID = CBUUID(string: "CB0CC42D-8F20-4FA7-A224-DBC1707CF89A")
    
    var peripheralManager: CBPeripheralManager!
    
    
    deinit {
        Antenna.sharedAntenna.stopAdvertising()
    }

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        let antenna: Antenna = Antenna.sharedAntenna
        
        // Characteristic
        let currentUserID: Data = "id".data(using: String.Encoding.utf8)!
        let userID: CBMutableCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: .read, value: currentUserID, permissions: .readable)
        
        // Service

        let service: CBMutableService = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [userID]
        
        antenna.localName = "Antenna"
        antenna.serviceUUIDs = [serviceUUID]
        antenna.services = [service]
        
        antenna.createDeviceBlock = { (peripheral, characteristic) in
            if characteristic.uuid.isEqual(userID) {
                if let idData: Data = characteristic.value, let id: String = String(data: idData, encoding: String.Encoding.utf8){
                    return Antenna.Device(id: id, peripheral: peripheral)
                }
            }
            return nil
        }
        
        Antenna.sharedAntenna.startAndReady { (antenna) -> Void in
            
            antenna.startAdvertising()
            antenna.startScan()
            
        }
        
    }

    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {

        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Antenna.sharedAntenna.connectedDevices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let object = Antenna.sharedAntenna.connectedDevices.sorted { (device1, device2) -> Bool in
            return device1.id > device2.id
        }
        cell.textLabel!.text = object.description
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    func antenna(_ antenna: Antenna, didChangeConnectedPeripherals peripherals: [CBPeripheral]) {
        DispatchQueue.main.async { () -> Void in
            self.tableView.reloadData()
        }
    }

}

