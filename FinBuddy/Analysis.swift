//
//  Analysis.swift
//  FinBuddy
//
//  Immutable analysis snapshot model matching PRD schema.
//

import Foundation
import SwiftData

struct CategoryTotal: Codable, Hashable {
    let category: Category
    let total: Decimal
}

struct CategoryDelta: Codable, Hashable {
    let category: Category
    let deltaPct: Double
}

@Model
final class Analysis {
    var id: UUID
    var createdAt: Date
    var periodStart: Date
    var periodEnd: Date

    // Snapshot payload - stored as Data for complex types
    @Attribute(.externalStorage) var topCategoriesData: Data
    @Attribute(.externalStorage) var deltasData: Data
    var recurringMerchants: [String]
    var insights: [String]
    var summary: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        periodStart: Date,
        periodEnd: Date,
        topCategories: [CategoryTotal],
        deltas: [CategoryDelta],
        recurringMerchants: [String],
        insights: [String],
        summary: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.topCategoriesData = (try? JSONEncoder().encode(topCategories)) ?? Data()
        self.deltasData = (try? JSONEncoder().encode(deltas)) ?? Data()
        self.recurringMerchants = recurringMerchants
        self.insights = insights
        self.summary = summary
    }
    
    // Computed properties for convenience
    var topCategories: [CategoryTotal] {
        (try? JSONDecoder().decode([CategoryTotal].self, from: topCategoriesData)) ?? []
    }
    
    var deltas: [CategoryDelta] {
        (try? JSONDecoder().decode([CategoryDelta].self, from: deltasData)) ?? []
    }
}
