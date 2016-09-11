//
//  Antenna.swift
//  Antenna
//
//  Created by 1amageek on 2016/01/01.
//  Copyright © 2016年 Stamp inc. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

/**
 AntennaはCoreBluetoothを使って任意のサービスを持つPeripheralを見つけ出します。
 PeripheralControllerを有し、見つけたPeripheralの制御をします。
 */

struct AntennaStatus: OptionSet {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }
    static let AntennaIsBusy = AntennaStatus(rawValue: 0)
    static let CentralManagerIsReady = AntennaStatus(rawValue: 1)
    static let PeripheralManagerIsReady = AntennaStatus(rawValue: 2)
    static let AntennaIsReady: AntennaStatus = [CentralManagerIsReady, PeripheralManagerIsReady]
}

let AntennaDidChangeConnectedPeripherals: String = "antenna.did.change.connected.peripherals"
let AntennaDidChangeConnectedDevices: String = "antenna.did.change.connected.devices"
let AntennaPeripheralsKey: String = "antenna.peripherals.key"
let AntennaDevicesKey: String = "antenna.devices.key"

open class Antenna: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {
    
    open var centralRestoreIdentifierKey = "antenna.central"
    open var peripheralRestoreIdentifierKey = "antenna.peripheral"
    
    open fileprivate(set) var peripheralManager: CBPeripheralManager!
    open fileprivate(set) var centralManager: CBCentralManager!
    
    /// Queue
    let queue: DispatchQueue = DispatchQueue.global(qos: .background)
    
    /// Antenna status
    var status: AntennaStatus! {
        didSet {
            if status == .AntennaIsReady {
                debugPrint("Antenna is ready..")
                if self.readyClosure != nil {
                    self.readyClosure!(self)
                }
            }
        }
    }
    
    /**
     Requirement paramaters
     */
    
    /// Local name
    var localName: String?
    
    /// Advertising & Scanning service UUIDs
    var serviceUUIDs: [CBUUID]? {
        willSet {
            if self.centralManager.isScanning {
                debugPrint("Antenna is scanning. To change the Service, it is necessary to stop scanning.")
            }
        }
    }
    
    /// Advertising Service
    var services: [CBMutableService]? {
        didSet {
            for service: CBMutableService in services! {
                // 同じサービスを追加しても先に公開されているサービスが優先される
                self.peripheralManager.add(service)
            }
        }
    }
    
    /// Discoverd peripherals
    var discoveredPeripherals: Set<CBPeripheral> = []
    
    /// Connected peripherals
    var connectedPeripherals: Set<CBPeripheral> = [] {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AntennaDidChangeConnectedPeripherals), object: self, userInfo: [AntennaPeripheralsKey: self.connectedPeripherals])
            }
        }
    }
    
    /// Connected devices
    var connectedDevices: Set<Device> = [] {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AntennaDidChangeConnectedDevices), object: self, userInfo: [AntennaDevicesKey: self.connectedDevices])
            }
        }
    }
    
    // MARK: -
    
    var optionsOfScan: [String : AnyObject] {
        return [CBCentralManagerScanOptionAllowDuplicatesKey: false as AnyObject]
    }
    
    func applicationDidEnterBackground() {
        self.stopScan()
    }
    
    func applicationWillResignActive() {
        self.startScan()
    }
    
    class func setup() {
        _ = Antenna.sharedAntenna
    }
    
    static let sharedAntenna: Antenna = {
        let antenna = Antenna()
        return antenna
    }()
    
    override init() {
        super.init()
        self.status = AntennaStatus.AntennaIsBusy
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: self.queue, options: [CBPeripheralManagerOptionRestoreIdentifierKey: self.peripheralRestoreIdentifierKey])
        self.centralManager = CBCentralManager(delegate: self, queue: self.queue, options: [CBCentralManagerOptionRestoreIdentifierKey: self.centralRestoreIdentifierKey])
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK - method
    
    var readyClosure: ((_ antenna: Antenna) -> ())?
    func startAndReady(_ readyClosure:@escaping (_ antenna: Antenna) -> Void) {
        self.readyClosure = readyClosure
    }
    
    var createDeviceBlock: ((_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) -> Device?)?
    
    /**
     Scan
     */
    
    /// Antenna is scanning
    var isScanning: Bool {
        return self.centralManager.isScanning
    }
    
    /// Start scan
    func startScan() {
        if !isScanning {
            self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: self.optionsOfScan)
            debugPrint("Antenna is start scanning..")
        }
    }
    
    /// Clear and scan
    func reScan() {
        self.centralManager.stopScan()
        self.cleanup()
        self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: self.optionsOfScan)
    }
    
    /// Stop scan
    func stopScan() {
        self.centralManager.stopScan()
        self.discoveredPeripherals = []
    }
    
    /**
     Advertising
     */
    
    // Start advertising
    func startAdvertising() {
        var advertisementData: [String: AnyObject] = [:]
        guard let serviceUUIDs: [CBUUID] = self.serviceUUIDs else {
            debugPrint("Antenna is requried serviceUUIDs")
            return
        }
        advertisementData[CBAdvertisementDataServiceUUIDsKey] = serviceUUIDs as AnyObject?
        if let localName: String = self.localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName as AnyObject?
        }
        if !self.peripheralManager.isAdvertising {
            self.peripheralManager.startAdvertising(advertisementData)
            debugPrint("Start advertising", advertisementData)
        }
    }
    
    /// Stop advertising
    func stopAdvertising() {
        self.peripheralManager.stopAdvertising()
    }
    
    /// cleanup
    func cleanup() {
        self.discoveredPeripherals = []
        self.connectedPeripherals = []
        self.connectedDevices = []
    }
    
    // MARK: - CBCentralManagerDelegate
    
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            self.status.insert(AntennaStatus.CentralManagerIsReady)
            break
        case .poweredOff: break
        case .resetting: break
        case .unauthorized: break
        case .unknown: break
        case .unsupported: break
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        debugPrint("didDiscoverPeripheral", peripheral)
        if !self.discoveredPeripherals.contains(peripheral) {
            self.discoveredPeripherals.insert(peripheral)
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugPrint("didConnectPeripheral", peripheral)
        if !self.connectedPeripherals.contains(peripheral) {
            self.connectedPeripherals.insert(peripheral)
            if let serivces: [CBService] = self.services {
                let serviceUUIDs: [CBUUID] = serivces.map { (service: CBService) -> CBUUID in
                    return service.uuid
                }
                peripheral.delegate = self
                peripheral.discoverServices(serviceUUIDs)
            }
        }
        self.discoveredPeripherals.remove(peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debugPrint("didFailToConnectPeripheral", peripheral)
        if let error = error {
            debugPrint("didFailToConnectPeripheral", error)
        }
        self.connectedPeripherals.remove(peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("didDisconnectPeripheral", peripheral)
        if let error = error {
            debugPrint("didDisconnectPeripheral", error)
        }
        self.connectedPeripherals.remove(peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        //let peripherals: [CBPeripheral] = dict[CBAdvertisementDataLocalNameKey]
    }
    
    
    // MARK: - CBPeripheralDelegate
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        debugPrint("didDiscoverServices", peripheral)
        if let error = error {
            debugPrint("didDiscoverServices", error)
        } else {
            let characteristicUUIDs: [CBUUID] = self.services!.flatMap { $0.characteristics! }.flatMap({ $0.uuid })
            for service in peripheral.services! {
                peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
            }
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            debugPrint("didDiscoverCharacteristicsForService", error)
        } else {
            let characteristicUUIDs: [CBUUID] = self.services!.flatMap { $0.characteristics! }.flatMap({ $0.uuid })
            for characteristic in service.characteristics! {
                if characteristicUUIDs.contains(characteristic.uuid) {
                    let properties: CBCharacteristicProperties = characteristic.properties
                    if properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                    // FIXME .Read ....
                }
            }
        }
    }
    
    open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        debugPrint("peripheralDidUpdateName", peripheral)
    }
    
    open func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            debugPrint("peripheralDidUpdateRSSI", error)
        } else {
            
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            debugPrint("didReadRSSI", error)
        } else {
            
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            debugPrint("didDiscoverDescriptorsForCharacteristic", error)
        } else {
            
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        if let error = error {
            debugPrint("didDiscoverIncludedServicesForService", error)
        } else {
            
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            debugPrint("didUpdateNotificationStateForCharacteristic", error)
        } else {
            
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            if let device: Device = self.createDeviceBlock?(peripheral, characteristic) {
                objc_sync_enter(self)
                if !connectedDevices.contains(device) {
                    self.connectedDevices.insert(device)
                }
                objc_sync_exit(self)
                // FIXME
            }
        }
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    open func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
        case .poweredOn: self.status.insert(AntennaStatus.PeripheralManagerIsReady)
        case .poweredOff: self.cleanup()
        case .resetting: break
        case .unauthorized: break
        case .unknown: break
        case .unsupported: break
        }
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        
    }
    
    open func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            debugPrint("peripheralManagerDidStartAdvertising", peripheral)
        }
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        
    }
    
    open func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
    }
    
    // MARK: -
    
    internal func _debug() {
        debugPrint("discoveredPeripherals", self.discoveredPeripherals)
        debugPrint("connectedPeripherals ", self.connectedPeripherals)
        debugPrint("connectedDevices ", self.connectedDevices)
    }
    
    // MARK: - Device
    
    open class Device: Hashable {
        var peripheral: CBPeripheral
        var id: String
        init(id: String, peripheral: CBPeripheral) {
            self.id = id
            self.peripheral = peripheral
        }
    }
    
}

extension Antenna.Device {
    public var hashValue: Int {
        return self.id.hash
    }
}

public func ==<T: Antenna.Device>(lhs: T, rhs: T) -> Bool {
    return lhs.id == rhs.id
}
