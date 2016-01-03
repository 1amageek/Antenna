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
    
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
    
    var state: AntennaStatus!
    var peripheralManager: CBPeripheralManager!
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral?
    var connectedPeripherals: [CBPeripheral]! = []
    var services: [CBMutableService]?
    weak var delegate: AntennaDelegate?
    
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
    
    func scanForPeripheralsWithServices(serviceUUIDs: [CBUUID]?) {
        print(__FUNCTION__)
        let serviceUUIDs = services?.flatMap({$0.UUID})
        let options: [String: AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey:false]
        self.centralManager.scanForPeripheralsWithServices(serviceUUIDs, options: options)
    }
    
    func startAdvertising(advertisementData: [String : AnyObject]?) {
        print(__FUNCTION__)
        guard let advertisementData = advertisementData else {
            return
        }
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
        if self.discoveredPeripheral != peripheral {
            self.discoveredPeripheral = peripheral
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print(__FUNCTION__)
        if !self.connectedPeripherals.contains(peripheral) {
            self.connectedPeripherals.append(peripheral)
            self.delegate!.antenna(self, didChangeConnectedPeripherals: self.connectedPeripherals)
            
            let serviceUUIDs: [CBUUID] = self.services!.map { (service: CBService) -> CBUUID in
                return service.UUID
            }
            peripheral.delegate = self
            peripheral.discoverServices(serviceUUIDs)
        }
        self.discoveredPeripheral = nil
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print(__FUNCTION__)
        print(error!)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print(__FUNCTION__)
        if self.connectedPeripherals.contains(peripheral) {
            let index: Int = self.connectedPeripherals.indexOf(peripheral)!
            self.connectedPeripherals.removeAtIndex(index)
            self.delegate!.antenna(self, didChangeConnectedPeripherals: self.connectedPeripherals)
        }
        print(error!)
    }
    
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        //let peripherals: [CBPeripheral] = dict[CBAdvertisementDataLocalNameKey]
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print(__FUNCTION__)
        let characteristicUUID: [CBUUID] = self.services!.flatMap { $0.characteristics! }.flatMap({$0.UUID})
        for (_, service) in (peripheral.services?.enumerate())! {
            peripheral.discoverCharacteristics(characteristicUUID, forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        print(__FUNCTION__)
//        for (_, characteristic) in (service.characteristics?.enumerate())! {
//            if characteristic.UUID.isEqual(self.locationCharacteristicUUID) {
//                // TODO
//            }
//        }
    }
    
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
            for service in services! {
                peripheral.addService(service)
            }
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

protocol AntennaDelegate: NSObjectProtocol {
    func antenna(antenna: Antenna, didChangeConnectedPeripherals peripherals: [CBPeripheral])
}
