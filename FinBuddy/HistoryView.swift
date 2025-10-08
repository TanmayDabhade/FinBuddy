// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/HistoryView.swift
// History: list saved analyses with read-only detail view

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: [SortDescriptor(\Analysis.createdAt, order: .reverse)]) private var analyses: [Analysis]

    var body: some View {
        NavigationStack {
            List {
                if analyses.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Your saved analyses will appear here.")
                    )
                } else {
                    ForEach(analyses) { a in
                        NavigationLink {
                            AnalysisSnapshotView(analysis: a)
                                .navigationTitle("Snapshot")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(a.summary)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text("Period: \(a.periodStart.formatted(date: .abbreviated, time: .omitted)) – \(a.periodEnd.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Analysis snapshot")
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
