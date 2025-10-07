//
//  Item.swift
//  FinBuddy
//
//  Created by Tanmay Avinash Dabhade on 10/6/25.
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
