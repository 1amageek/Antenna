//
//  Antenna.swift
//  Antenna
//
//  Created by 1amageek on 2016/01/01.
//  Copyright © 2016年 Stamp inc. All rights reserved.
//

import Foundation
import CoreBluetooth

class Antenna: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {
    
    private let centralRestoreIdentifierKey = "inc.stamp.antenna.central"
    private let peripheralRestoreIdentifierKey = "inc.stamp.antenna.peripheral"
    
    // Characteristic
    private let locationCharacteristicUUID = CBUUID(string: "3E770C8F-DB75-43AA-A335-1013A728BF42")
    private(set) lazy var locationCharacteristic: CBMutableCharacteristic = {
        var locationCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: self.locationCharacteristicUUID, properties: .Broadcast, value: nil, permissions: .Readable)
        return locationCharacteristic
    }()
    
    // Service
    private let locationServiceUUID = CBUUID(string: "6257CA2B-59EE-4C50-8875-C7229FCFFCBA")
    private(set) lazy var locationService: CBMutableService = {
        var locationService: CBMutableService = CBMutableService(type: self.locationServiceUUID, primary: true)
        locationService.characteristics = [self.locationCharacteristic]
        return locationService
    }()
    
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
    
    private(set) lazy var centralManager: CBCentralManager = {
        var centralManager = CBCentralManager(delegate: self, queue: self.queue, options: [CBCentralManagerOptionRestoreIdentifierKey: self.centralRestoreIdentifierKey])
        return centralManager
    }()
    
    private(set) lazy var peripheralManager: CBPeripheralManager = {
        var peripheralManager: CBPeripheralManager = CBPeripheralManager(delegate: self, queue: self.queue, options: [CBPeripheralManagerOptionRestoreIdentifierKey: self.peripheralRestoreIdentifierKey])
        peripheralManager.addService(self.locationService)
        return peripheralManager
    }()
    
    static let sharedAntenna: Antenna = {
        let antenna = Antenna()
        
        // setup
        
        return antenna
    }()
    
    // MARK - method
    
    internal func scanForPeripheralsWithServices(serviceUUIDs: [String]?) {
        
        let UUIDs = serviceUUIDs!.map { (uuid) -> CBUUID in
            return CBUUID(string: uuid)
        }
        
        let options: [String: AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey:false]
        centralManager.scanForPeripheralsWithServices(UUIDs, options: options)
    }
    
    func startAdvertising(advertisementData: [String : AnyObject]?) {
        peripheralManager.startAdvertising(advertisementData)a
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print(peripheral)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
    }
    
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        //let peripherals: [CBPeripheral] = dict[CBAdvertisementDataLocalNameKey]
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
        
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        guard peripheral.state != CBPeripheralManagerState.PoweredOff else {
            return
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        if error != nil { print(error) }
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, willRestoreState dict: [String : AnyObject]) {
        
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        
    }


    
    
    
}