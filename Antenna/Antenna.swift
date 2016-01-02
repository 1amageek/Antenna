//
//  Antenna.swift
//  Antenna
//
//  Created by 1amageek on 2016/01/01.
//  Copyright © 2016年 Stamp inc. All rights reserved.
//

import Foundation
import CoreBluetooth

struct AntennaStatus: OptionSetType {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }
    static let AntennaIsBusy = AntennaStatus(rawValue: 0)
    static let CentralManagerIsReady = AntennaStatus(rawValue: 1)
    static let PeripheralManagerIsReady = AntennaStatus(rawValue: 2)
    static let AntennaIsReady: AntennaStatus = [CentralManagerIsReady, CentralManagerIsReady]
}

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
    /*
    private(set) lazy var centralManager: CBCentralManager = {
        var centralManager = CBCentralManager(delegate: self, queue: self.queue, options: [CBCentralManagerOptionRestoreIdentifierKey: self.centralRestoreIdentifierKey])
        return centralManager
    }()
    
    private(set) lazy var peripheralManager: CBPeripheralManager = {
        var peripheralManager: CBPeripheralManager = CBPeripheralManager(delegate: self, queue: self.queue, options: [CBPeripheralManagerOptionRestoreIdentifierKey: self.peripheralRestoreIdentifierKey])
        return peripheralManager
    }()
    */
    var state: AntennaStatus!
    var peripheralManager: CBPeripheralManager!
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral]! = []
    var connectedPeripherals: [CBPeripheral]! = []
    
    static let sharedAntenna: Antenna = {
        let antenna = Antenna()
        // setup
        antenna.state = AntennaStatus.AntennaIsBusy
        antenna.peripheralManager = CBPeripheralManager(delegate: antenna, queue: antenna.queue, options: [CBPeripheralManagerOptionRestoreIdentifierKey: antenna.peripheralRestoreIdentifierKey])
        antenna.centralManager = CBCentralManager(delegate: antenna, queue: antenna.queue, options: [CBCentralManagerOptionRestoreIdentifierKey: antenna.centralRestoreIdentifierKey])
        return antenna
    }()
    
    // MARK - method
    
    var peripheralReadyBlock: (() -> ())?
    var centralReadyBlock: (() -> ())?
    func startAndReady(peripheralIsReadyHandler:() -> Void, centralIsReadyHandler:() -> Void) {
        peripheralReadyBlock = peripheralIsReadyHandler
        centralReadyBlock = centralIsReadyHandler
    }
    
    private var _serviceUUIDs: [CBUUID]?
    func scanForPeripheralsWithServices(serviceUUIDs: [CBUUID]?) {
        print(__FUNCTION__)
        guard let serviceUUIDs = serviceUUIDs else {
            return
        }
        self._serviceUUIDs = serviceUUIDs
        
        let options: [String: AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey:false]
        self.centralManager.scanForPeripheralsWithServices(serviceUUIDs, options: options)
    }
    
    private var _advertisementData: [String: AnyObject]?
    func startAdvertising(advertisementData: [String : AnyObject]?) {
        print(__FUNCTION__)
        guard let advertisementData = advertisementData else {
            return
        }
        self._advertisementData = advertisementData
        self.peripheralManager.startAdvertising(advertisementData)
    }
    
    func stopAdvertising() {
        print(__FUNCTION__)
        self.peripheralManager.stopAdvertising()
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        print(__FUNCTION__)
        switch central.state {
        case .PoweredOn:
            self.state = AntennaStatus.CentralManagerIsReady
            if self.centralReadyBlock != nil {
                self.centralReadyBlock!()
            }
            break
        case .PoweredOff: break
        case .Resetting: break
        case .Unauthorized: break
        case .Unknown: break
        case .Unsupported: break
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print(__FUNCTION__)
        print(peripheral)
        
        if !self.discoveredPeripherals.contains(peripheral) {
            self.discoveredPeripherals.append(peripheral)
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
        
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print(__FUNCTION__)
        peripheral.delegate = self
        self.connectedPeripherals.append(peripheral)
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print(__FUNCTION__)
        print(error!)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print(__FUNCTION__)
        let index: Int = self.connectedPeripherals.indexOf(peripheral)!
        self.connectedPeripherals.removeAtIndex(index)
        print(self.connectedPeripherals)
        print(error!)
    }
    
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        //let peripherals: [CBPeripheral] = dict[CBAdvertisementDataLocalNameKey]
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        print(__FUNCTION__)
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
        print(__FUNCTION__)
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        print(__FUNCTION__)
        switch peripheral.state {
        case .PoweredOn:
            self.state = AntennaStatus.PeripheralManagerIsReady
            peripheral.addService(self.locationService)
            if self.peripheralReadyBlock != nil {
                peripheralReadyBlock!()
            }
            break
        case .PoweredOff: break
        case .Resetting: break
        case .Unauthorized: break
        case .Unknown: break
        case .Unsupported: break
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        print(__FUNCTION__)
        print(service)
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, willRestoreState dict: [String : AnyObject]) {
        
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        print(__FUNCTION__)
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        print(__FUNCTION__)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        print(__FUNCTION__)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        print(__FUNCTION__)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        print(__FUNCTION__)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        print(__FUNCTION__)
    }

}
