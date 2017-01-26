//
//  Communicable.swift
//  Antenna
//
//  Created by 1amageek on 2017/01/25.
//  Copyright © 2017年 Stamp inc. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol Communicable {
    var serviceUUIDs: [CBUUID] { get }
    var characteristicUUIDs: [CBUUID] { get }
}
