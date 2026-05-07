//
//  Item.swift
//  BlueAssistMac
//
//  Created by Jatin Rakesh on 7/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
