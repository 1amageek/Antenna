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


open class Antenna: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, Communicable {
    
    static let `default`: Antenna = Antenna()
    
    public var readValueBlock: ((CBPeripheral, CBCharacteristic) -> Void)?
    
    public var writeValueBlock: ((CBPeripheral, CBCharacteristic) -> Void)?
    
    public var changeConnectedPeripheralsBlock: ((Set<CBPeripheral>) -> Void)?
    
    public var changeConnectedDevicesBlock: ((Set<Device>) -> Void)?
    
    public var createDeviceBlock: ((_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) -> Device?)?
    
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
                self.changeConnectedPeripheralsBlock?(self.connectedPeripherals)
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
                self.changeConnectedDevicesBlock?(self.connectedDevices)
            }
        }
    }
    
    private var thresholdRSSI: NSNumber?
    
    private var allowDuplicates: Bool = false
    
    private var scanOptions: [String: Any]?
    
    private var startScanBlock: (([String : Any]?) -> Void)?
    
    private var didUpdateValueBlock: ((CBCharacteristic, Error?) -> Void)?
    
    private var timeoutWorkItem: DispatchWorkItem?
    
    // MARK: -
    
    func applicationDidEnterBackground() {
        stopScan()
    }
    
    func applicationWillResignActive() {
        // TODO:
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
    
    /**
     Scan
     */
    
    /// Antenna is scanning
    var isScanning: Bool {
        return self.centralManager.isScanning
    }
    
    /// Start scan
    
    func startScan(thresholdRSSI: NSNumber? = nil, allowDuplicates: Bool = false, options: [String: Any]? = nil) {
        self.thresholdRSSI = thresholdRSSI
        self.allowDuplicates = allowDuplicates
        if let options: [String: Any] = options {
            self.scanOptions = options
        } else {
            let options: [String: Any] = [
                CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates,
                CBCentralManagerScanOptionSolicitedServiceUUIDsKey: self.serviceUUIDs
            ]
            self.scanOptions = options
        }
        
        if #available(iOS 10.0, *) {
            if status == .poweredOn {
                if !isScanning {
                    self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: self.scanOptions)
                    debugPrint("[Antenna Antenna] start scan.")
                }
            } else {
                self.startScanBlock = { [unowned self] (options) in
                    if !self.isScanning {
                        self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: self.scanOptions)
                        debugPrint("[Antenna Antenna] start scan.")
                    }
                }
            }
        } else {
            self.startScanBlock = { [unowned self] (options) in
                if !self.isScanning {
                    self.centralManager.scanForPeripherals(withServices: self.serviceUUIDs, options: self.scanOptions)
                    debugPrint("[Antenna Antenna] start scan.")
                }
            }
        }
        
        let workItem: DispatchWorkItem = DispatchWorkItem {
            if self.centralManager.isScanning {
                self.stopScan()
            }
            self.timeoutWorkItem = nil
        }
        
        self.timeoutWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(20), execute: workItem)
        
    }
    
    
    /// Clear and scan
    func reScan() {
        self.stopScan()
        self.cleanup()
        self.startScan(thresholdRSSI: self.thresholdRSSI, allowDuplicates: self.allowDuplicates, options: self.scanOptions)
    }
    
    /// Stop scan
    func stopScan() {
        self.timeoutWorkItem?.cancel()
        self.centralManager.stopScan()
        debugPrint("[Antenna Antenna] Stop scan.")
    }
    
    /// cleanup
    func cleanup() {
        self.discoveredPeripherals = []
        self.connectedPeripherals = []
        self.connectedDevices = []
        self.readValueBlock = nil
        self.writeValueBlock = nil
        self.changeConnectedPeripheralsBlock = nil
        self.changeConnectedDevicesBlock = nil
        self.thresholdRSSI = nil
        self.scanOptions = nil
        self.didUpdateValueBlock = nil
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
        if let thresholdRSSI: NSNumber = self.thresholdRSSI {
            if thresholdRSSI.intValue < RSSI.intValue {
                self.centralManager.connect(peripheral, options: nil)
                stopScan()
            }
        } else {
            self.centralManager.connect(peripheral, options: nil)
        }
        
        debugPrint("[Antenna Antenna] discover peripheral. ", peripheral, RSSI)
        
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
                    self.readValueBlock?(peripheral, characteristic)
                }
                if properties.contains(.write) {
                    self.writeValueBlock?(peripheral, characteristic)
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
        didUpdateValueBlock?(characteristic, error)
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
