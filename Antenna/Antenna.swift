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

let AntennaDidChangeConnectedPeripherals: String = "antenna.did.change.connected.peripherals"
let AntennaDidChangeConnectedDevices: String = "antenna.did.change.connected.devices"
let AntennaPeripheralsKey: String = "antenna.peripherals.key"
let AntennaDevicesKey: String = "antenna.devices.key"

open class Antenna: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, Communicable {
    
    static let `default`: Antenna = Antenna()
    
    private let restoreIdentifierKey = "antenna.antenna.restore.key"
    
    private lazy var centralManager: CBCentralManager = {
        let options: [String: Any] = [CBCentralManagerOptionRestoreIdentifierKey: self.restoreIdentifierKey]
        let manager: CBCentralManager = CBCentralManager(delegate: self, queue: self.queue, options: options)
        return manager
    }()
    
    /// Queue
    private let queue: DispatchQueue = DispatchQueue(label: "antenna.antenna.queue")
    
    /// Discoverd peripherals
    private(set) var discoveredPeripherals: Set<CBPeripheral> = []
    
    /// Connected peripherals
    private(set) var connectedPeripherals: Set<CBPeripheral> = [] {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AntennaDidChangeConnectedPeripherals), object: self, userInfo: [AntennaPeripheralsKey: self.connectedPeripherals])
            }
        }
    }
    
    @available(iOS 10.0, *)
    var status: CBManagerState {
        return self.centralManager.state
    }
    
    /// Connected devices
    var connectedDevices: Set<Device> = [] {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AntennaDidChangeConnectedDevices), object: self, userInfo: [AntennaDevicesKey: self.connectedDevices])
            }
        }
    }
    
    private var scanOptions: [String: Any]?
    
    private var startScanBlock: (([String : Any]?) -> Void)?
    
    // MARK: -
    
    func applicationDidEnterBackground() {
        //self.stopScan()
    }
    
    func applicationWillResignActive() {
        //self.startScan()
    }
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK - method

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
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        startScan(options: options)
    }
    
    func startScan(options: [String: Any]?) {        
        self.scanOptions = options
        if #available(iOS 10.0, *) {
            if status == .poweredOn {
                if !isScanning {
                    self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: options)
                    debugPrint("[Antenna Antenna] start scan.")
                }
            } else {
                self.startScanBlock = { [unowned self] (options) in
                    if !self.isScanning {
                        self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: options)
                        debugPrint("[Antenna Antenna] start scan.")
                    }
                }
            }
        } else {
            self.startScanBlock = { [unowned self] (options) in
                if !self.isScanning {
                    self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: options)
                    debugPrint("[Antenna Antenna] start scan.")
                }
            }
        }

    }
    
    /// Clear and scan
    func reScan() {
        self.stopScan()
        self.cleanup()
        self.startScan()
    }
    
    /// Stop scan
    func stopScan() {
        self.centralManager.stopScan()
        self.discoveredPeripherals = []
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
        case .poweredOn: self.startScanBlock?(self.scanOptions)
        case .unauthorized: break
        default:
            break
        }
    }
    
    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.discoveredPeripherals.insert(peripheral)
        self.centralManager.connect(peripheral, options: nil)
        debugPrint("[Antenna Antenna] discover peripheral. ", peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(self.serviceUUIDs)
        self.connectedPeripherals.insert(peripheral)
        debugPrint("[Antenna Antenna] donnect peripheral. ", peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debugPrint("[Antenna Antenna] fail to connect peripheral. ", peripheral, error ?? "")
        self.connectedPeripherals.remove(peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("[Antenna Antenna] did disconnect peripheral. ", peripheral, error ?? "")
        self.connectedPeripherals.remove(peripheral)
    }
    
    open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        //let peripherals: [CBPeripheral] = dict[CBAdvertisementDataLocalNameKey]
    }
    
    
    // MARK: - CBPeripheralDelegate
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        debugPrint("[Antenna Antenna] did discover service. peripheral", peripheral, error ?? "")
        guard let services: [CBService] = peripheral.services else {
            return
        }
        debugPrint("[Antenna Antenna] did discover service. services", services)
        for service in services {
            peripheral.discoverCharacteristics(self.characteristicUUIDs, for: service)
        }
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugPrint("[Antenna Antenna] did discover characteristics for service. ", peripheral, error ?? "")
        for characteristic in service.characteristics! {
            if self.characteristicUUIDs.contains(characteristic.uuid) {
                let properties: CBCharacteristicProperties = characteristic.properties
                debugPrint("[Antenna Antenna] characteristic properties. ", properties)
                if properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        debugPrint("[Antenna Antenna] update name ", peripheral)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        debugPrint("[Antenna Antenna] did read RSSI ", RSSI)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("[Antenna Antenna] did discover descriptors for ", peripheral, characteristic)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        debugPrint("[Antenna Antenna] did discover included services for ", peripheral, service)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("[Antenna Antenna] did update notification state for ", peripheral, characteristic)
    }
    
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("[Antenna Antenna] did update value for ", peripheral, characteristic)
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
