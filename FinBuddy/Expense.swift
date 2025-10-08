// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/Expense.swift
//
//  Expense.swift
//  FinBuddy
//
//  Defines Expense model and supporting enums per PRD.
//

import Foundation
import SwiftData

@Model
final class Expense {
    // Core fields
    var id: UUID
    var title: String
    var amount: Decimal
    var date: Date
    var merchant: String?
    var category: Category?
    var source: Source
    var notes: String?
    var createdAt: Date

    // Import & categorization helpers
    var importBatchID: UUID? // for demo import undo batching
    var isCategoryUncertain: Bool

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        date: Date,
        merchant: String? = nil,
        category: Category? = nil,
        source: Source,
        notes: String? = nil,
        createdAt: Date = Date(),
        importBatchID: UUID? = nil,
        isCategoryUncertain: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.category = category
        self.source = source
        self.notes = notes
        self.createdAt = createdAt
        self.importBatchID = importBatchID
        self.isCategoryUncertain = isCategoryUncertain
    }
}

enum Category: String, Codable, CaseIterable, Identifiable {
    case food, transport, shopping, bills, entertainment, health, education, rent, other
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .bills: return "Bills"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .education: return "Education"
        case .rent: return "Rent"
        case .other: return "Other"
        }
    }
}

enum Source: String, Codable { case manual, csvImport }

extension Category {
    /// Best-effort mapping from arbitrary string to Category. Returns nil if unknown.
    static func fromString(_ raw: String?) -> Category? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "food", "dining", "groceries", "restaurant", "restaurants": return .food
        case "transport", "travel", "commute", "uber", "lyft", "taxi", "fuel", "gas": return .transport
        case "shopping", "retail", "amazon": return .shopping
        case "bills", "utilities", "rent", "mortgage", "phone", "electricity", "water": return .bills
        case "entertainment", "movies", "music", "games": return .entertainment
        case "health", "healthcare", "medical", "pharmacy", "fitness", "gym": return .health
        case "education", "tuition", "courses", "books": return .education
        case "other", "misc", "miscellaneous": return .other
        default: return nil
        }
    }
}
