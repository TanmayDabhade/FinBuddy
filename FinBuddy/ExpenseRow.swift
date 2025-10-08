// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/ExpenseRow.swift
// Reusable expense row for lists

import SwiftUI

struct ExpenseRow: View {
    enum Secondary { case merchant, date, none }

    let expense: Expense
    var secondary: Secondary = .merchant

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            let cat = expense.category
            ZStack {
                Circle()
                    .fill((cat?.color ?? .gray).opacity(0.15))
                Image(systemName: (cat?.symbolName) ?? "circle.grid.2x2")
                    .foregroundStyle(cat?.color ?? .gray)
                    .font(.subheadline)
            }
            .frame(width: 34, height: 34)

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.body)
                    .lineLimit(1)
                if let subtitle = subtitleText() {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount
            Text(UIFormat.currency(expense.amount))
                .font(.headline)
                .monospacedDigit()
        }
        .accessibilityLabel("Expense: \(expense.title), amount \(UIFormat.currency(expense.amount))")
    }

    private func subtitleText() -> String? {
        switch secondary {
        case .merchant:
            if let merchant = expense.merchant, !merchant.isEmpty { return merchant }
            return expense.date.formatted(date: .abbreviated, time: .omitted)
        case .date:
            return expense.date.formatted(date: .abbreviated, time: .omitted)
        case .none:
            return nil
        }
    }
}

#Preview {
    let e = Expense(title: "Coffee", amount: 4.5, date: .now, merchant: "Starbucks", category: .food, source: .manual)
    return List { ExpenseRow(expense: e) }
}
