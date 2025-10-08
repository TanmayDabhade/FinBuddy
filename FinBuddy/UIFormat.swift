//
//  UIFormat.swift
//  FinBuddy
//
//  Centralized formatting helpers for currency and dates used across the app.
//

import Foundation

// Consistent UI formatting helpers
enum UIFormat {
    static func currency(_ dec: Decimal, maxFractionDigits: Int? = nil) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        if let code = UserDefaults.standard.string(forKey: "currencyCode"), !code.isEmpty {
            nf.currencyCode = code
        }
        if let max = maxFractionDigits { nf.maximumFractionDigits = max }
        return nf.string(from: NSDecimalNumber(decimal: dec)) ?? "$0"
    }

    static func month(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date)
    }
}



