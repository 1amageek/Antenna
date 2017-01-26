//
//  Beacon.swift
//  Antenna
//
//  Created by 1amageek on 2017/01/25.
//  Copyright © 2017年 Stamp inc. All rights reserved.
//

import Foundation
import CoreBluetooth

class Beacon: NSObject, CBPeripheralManagerDelegate, Communicable {
    
    static let `default`: Beacon = Beacon()
    
    // MARK: - public
    
    public var localName: String?
    
    public var isAdvertising: Bool {
        return self.peripheralManager.isAdvertising
    }
    
    public var authorizationStatus: CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    @available(iOS 10.0, *)
    public var state: CBManagerState {
        return self.peripheralManager.state
    }
    
    public var poweredOffBlock: (() -> Void)?
    
    override init() {
        super.init()
        _ = self.peripheralManager
    }
    
    // MARK: - private
    
    private let queue: DispatchQueue = DispatchQueue(label: "antenna.beacon.queue", attributes: [], target: nil)
    
    private let restoreIdentifierKey: String = "antenna.beacon.restore.key"
    
    private var advertisementData: [String: Any]?
    
    private var startAdvertisingBlock: (([String : Any]?) -> Void)?
    
    private lazy var peripheralManager: CBPeripheralManager = {
        let options: [String: Any] = [CBPeripheralManagerOptionRestoreIdentifierKey: self.restoreIdentifierKey]
        let peripheralManager: CBPeripheralManager = CBPeripheralManager(delegate: self,
                                                                         queue: self.queue,
                                                                         options: options)
        return peripheralManager
    }()
    
    // MARK: - functions
    
    private func setup() {
        queue.async { [unowned self] in
            guard let service: CBMutableService = self.createService() else {
                return
            }
            self.services = [service]
        }
    }
    
    private var services: [CBMutableService]? {
        didSet {
            self.peripheralManager.removeAllServices()
            guard let services: [CBMutableService] = services else {
                return
            }
            for service: CBMutableService in services {
                self.peripheralManager.add(service)
            }
        }
    }
    
    public func startAdvertising() {        
        var advertisementData: [String: Any] = [:]
        
        // Set serviceUUIDs
        let serviceUUIDs: [CBUUID] = self.serviceUUIDs
        advertisementData[CBAdvertisementDataServiceUUIDsKey] = serviceUUIDs
        
        // Set localName. if beacon have localName
        if let localName: String = self.localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName
        }
        
        startAdvertising(advertisementData)
    }
    
    public func startAdvertising(_ advertisementData: [String : Any]?) {
        _startAdvertising(advertisementData)
    }
    
    private var canStartAdvertising: Bool = false
    
    private func _startAdvertising(_ advertisementData: [String : Any]?) {
        queue.async { [unowned self] in
            self.advertisementData = advertisementData
            self.startAdvertisingBlock = { [unowned self] (advertisementData) in
                if !self.isAdvertising {
                    self.peripheralManager.startAdvertising(advertisementData)
                    debugPrint("[Antenna Beacon] Start advertising", advertisementData ?? [:])
                } else {
                    debugPrint("[Antenna Beacon] Beacon has already advertising.")
                }
            }
            if self.canStartAdvertising {
                self.startAdvertisingBlock!(advertisementData)
            }
        }
    }
    
    public func stopAdvertising() {
        self.peripheralManager.stopAdvertising()
    }
    
    
    // MARK: -
    
    open func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            debugPrint("[Antenna Beacon] did update status POWERD ON")
            setup()
        case .poweredOff:
            debugPrint("[Antenna Beacon] did update status POWERD OFF")
        case .resetting:
            debugPrint("[Antenna Beacon] did update status RESETTING")
        case .unauthorized:
            debugPrint("[Antenna Beacon] did update status UNAUTHORIZED")
        case .unknown:
            debugPrint("[Antenna Beacon] did update status UNKNOWN")
        case .unsupported:
            debugPrint("[Antenna Beacon] did update status UNSUPPORTED")
        }
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        debugPrint("[Antenna Beacon] did add service service", service, error ?? "")
        self.canStartAdvertising = true
        self.startAdvertisingBlock?(self.advertisementData)
    }
    
    open func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        debugPrint("[Antenna Beacon] did start advertising", peripheral, error ?? "")
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        debugPrint("[Antenna Beacon] will restore state ", dict)
    }
    
    open func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        debugPrint("[Antenna Beacon] is ready to update subscribers ", peripheral)
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        debugPrint("[Antenna Beacon] did subscribe to ", peripheral, central, characteristic)
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        debugPrint("[Antenna Beacon] did unsubscribe from ", peripheral, central, characteristic)
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        debugPrint("[Antenna Beacon] did receive read ", peripheral, request)
    }
    
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        debugPrint("[Antenna Beacon] did receive write", peripheral, requests)
    }
    
}
