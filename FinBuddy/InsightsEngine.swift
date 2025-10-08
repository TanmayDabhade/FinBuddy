// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/InsightsEngine.swift
// Local insights computation for Dashboard/Insights

import Foundation

struct InsightsEngine {
    static func analyze(expenses: [Expense], prevExpenses: [Expense], periodStart: Date, periodEnd: Date) -> Analysis {
        // Totals by category
        let totals = totalsByCategory(expenses)
        let prevTotals = totalsByCategory(prevExpenses)

        let top = totals
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { CategoryTotal(category: $0.key, total: $0.value) }

        // Deltas vs previous period
        let categories = Set(totals.keys).union(prevTotals.keys)
        let deltas: [CategoryDelta] = categories.map { cat in
            let cur = totals[cat] ?? 0
            let prev = prevTotals[cat] ?? 0
            let deltaPct: Double
            if prev == 0 {
                deltaPct = cur == 0 ? 0 : 1.0
            } else {
                deltaPct = (NSDecimalNumber(decimal: cur).doubleValue / NSDecimalNumber(decimal: prev).doubleValue) - 1.0
            }
            return CategoryDelta(category: cat, deltaPct: deltaPct)
        }.sorted { abs($0.deltaPct) > abs($1.deltaPct) }

        // Recurring suspects: same merchant with ≥2 similar-amount transactions in period
        let recurring = recurringMerchants(expenses)

        // Summary + insights strings
        let totalSpend = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        let currency = currencyString(totalSpend)
        let summary = "Spent \(currency) across \(expenses.count) expenses between \(formattedDate(periodStart)) – \(formattedDate(periodEnd))."

        var insights: [String] = []
        if let top1 = top.first {
            insights.append("Top category: \(top1.category.displayName) (\(currencyString(top1.total))).")
        }
        if let biggestDelta = deltas.first {
            let sign = biggestDelta.deltaPct >= 0 ? "+" : ""
            let pct = String(format: "%.0f%%", biggestDelta.deltaPct * 100)
            insights.append("Biggest change vs prev: \(biggestDelta.category.displayName) (\(sign)\(pct)).")
        }
        if !recurring.isEmpty {
            insights.append("Recurring merchants: \(recurring.prefix(3).joined(separator: ", "))…")
        }

        return Analysis(
            periodStart: periodStart,
            periodEnd: periodEnd,
            topCategories: Array(top),
            deltas: deltas,
            recurringMerchants: recurring,
            insights: insights,
            summary: summary
        )
    }

    private static func totalsByCategory(_ expenses: [Expense]) -> [Category: Decimal] {
        var dict: [Category: Decimal] = [:]
        for e in expenses {
            let cat = e.category ?? .other
            dict[cat, default: 0] += e.amount
        }
        return dict
    }

    private static func currencyString(_ dec: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        return nf.string(from: NSDecimalNumber(decimal: dec)) ?? "$0"
    }

    private static func formattedDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: d)
    }

    private static func recurringMerchants(_ expenses: [Expense]) -> [String] {
        // Group by merchant and collect amounts
        let grouped = Dictionary(grouping: expenses) { (e: Expense) -> String? in
            guard let m = e.merchant, !m.isEmpty else { return nil }
            return m
        }.compactMapKeys { $0 } // drop nil keys
        
        var suspects: [String] = []
        for (merchant, items) in grouped {
            let amounts = items.map { NSDecimalNumber(decimal: $0.amount).doubleValue }.sorted()
            if hasSimilarPair(amounts) { suspects.append(merchant) }
        }
        
        // Fallback: if none by similarity, use merchants with >= 2 transactions
        if suspects.isEmpty {
            let counts = Dictionary(grouping: expenses.compactMap { $0.merchant }, by: { $0 }).mapValues { $0.count }
            suspects = counts.filter { $0.value >= 2 }.map { $0.key }
        }
        return suspects.sorted()
    }
    
    private static func hasSimilarPair(_ amounts: [Double]) -> Bool {
        guard amounts.count >= 2 else { return false }
        for i in 1..<amounts.count {
            let a = amounts[i-1], b = amounts[i]
            let diff = abs(a - b)
            let tol = max(1.0, 0.05 * max(a, b))
            if diff <= tol { return true }
        }
        return false
    }
}

private extension Dictionary {
    func compactMapKeys<WrappedKey>(_ transform: (Key) -> WrappedKey?) -> [WrappedKey: Value] {
        var result: [WrappedKey: Value] = [:]
        for (k, v) in self {
            if let nk = transform(k) { result[nk] = v }
        }
        return result
    }
}
