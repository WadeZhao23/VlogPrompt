//
//  Item.swift
//  VlogPrompt
//
//  Created by chambers on 2026/2/24.
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
