//
//  Communicable+.swift
//  Antenna
//
//  Created by 1amageek on 2017/01/25.
//  Copyright © 2017年 Stamp inc. All rights reserved.
//

import Foundation
import CoreBluetooth

extension Communicable {
    
    var serviceUUIDs: [CBUUID] {
        return [CBUUID(string: "3E770C8F-DB75-43AA-A335-1013A728BF42")]
    }
    
    var characteristicUUIDs: [CBUUID] {
        return [
            CBUUID(string: "CB0CC42D-8F20-4FA7-A224-DBC1707CF89A"),
            CBUUID(string: "AEB83B76-B49E-42F3-80E9-79B427768303")
        ]
    }
    
}

extension Communicable {
    
    func createService() -> CBMutableService? {
        
        guard let serviceUUID: CBUUID = self.serviceUUIDs.first else {
            return nil
        }
        
        let service: CBMutableService = CBMutableService(type: serviceUUID, primary: true)
        
        // Characteristic
        let currentUserID: Data = "user_id".data(using: String.Encoding.utf8)!
        let userID: CBMutableCharacteristic = CBMutableCharacteristic(type: CBUUID(string: "CB0CC42D-8F20-4FA7-A224-DBC1707CF89A"), properties: .read, value: currentUserID, permissions: .readable)
        
        let write: CBMutableCharacteristic = CBMutableCharacteristic(type: CBUUID(string: "AEB83B76-B49E-42F3-80E9-79B427768303"), properties: .write, value: nil, permissions: .writeable)
        
        service.characteristics = [userID, write]
        
        return service
    }
}
