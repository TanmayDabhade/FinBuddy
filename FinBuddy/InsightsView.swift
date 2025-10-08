// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/InsightsView.swift
// Minimal insights screen scaffold per PRD

import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: [SortDescriptor(\Analysis.createdAt, order: .reverse)]) private var analyses: [Analysis]

    var body: some View {
        NavigationStack {
            List {
                if analyses.isEmpty {
                    ContentUnavailableView(
                        "No insights yet",
                        systemImage: "lightbulb",
                        description: Text("Run an analysis from Dashboard.")
                    )
                } else {
                    ForEach(analyses) { a in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(a.summary).font(.headline)
                            Text("Period: \(a.periodStart.formatted(date: .abbreviated, time: .omitted)) – \(a.periodEnd.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Insight summary")
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
