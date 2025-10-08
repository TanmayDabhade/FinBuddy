//
//  AnalysisSnapshotView.swift
//  FinBuddy
//
//  Reusable read-only view to render an Analysis snapshot (summary + charts).
//

import SwiftUI
import Charts

struct AnalysisSnapshotView: View {
    let analysis: Analysis

    var body: some View {
        VStack(spacing: 20) {
            SummaryCard(analysis: analysis)
            CategoryBarChart(topCategories: analysis.topCategories)
            CategoryPieChart(topCategories: analysis.topCategories)

            if !analysis.deltas.isEmpty {
                DeltasCard(deltas: analysis.deltas)
            }
            if !analysis.insights.isEmpty {
                InsightsCard(insights: analysis.insights)
            }
            if !analysis.recurringMerchants.isEmpty {
                RecurringMerchantsCard(merchants: analysis.recurringMerchants)
            }
        }
        .padding()
    }
}

private struct SummaryCard: View {
    let analysis: Analysis
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Period Summary").font(.title2).bold()
            Text(analysis.summary).font(.body).foregroundStyle(.secondary)
            HStack {
                Text("Period: \(analysis.periodStart.formatted(date: .abbreviated, time: .omitted)) – \(analysis.periodEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .cardStyle()
    }
}

private struct CategoryBarChart: View {
    let topCategories: [CategoryTotal]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories").font(.title2).bold()
            if topCategories.isEmpty {
                Text("No data available").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding()
            } else {
                Chart(topCategories, id: \.category) { item in
                    BarMark(
                        x: .value("Amount", NSDecimalNumber(decimal: item.total).doubleValue),
                        y: .value("Category", item.category.displayName)
                    )
                    .foregroundStyle(by: .value("Category", item.category.displayName))
                }
                .frame(height: CGFloat(max(200, topCategories.count * 40)))
            }
        }
        .cardStyle()
    }
}

private struct CategoryPieChart: View {
    let topCategories: [CategoryTotal]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Distribution").font(.title2).bold()
            if topCategories.isEmpty {
                Text("No data available").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding()
            } else {
                Chart(topCategories, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", NSDecimalNumber(decimal: item.total).doubleValue),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", item.category.displayName))
                    .annotation(position: .overlay) {
                        Text(currencyString(item.total))
                            .font(.caption2).bold().foregroundStyle(.white)
                    }
                }
                .frame(height: 250)
                .chartLegend(position: .bottom, alignment: .center)
            }
        }
        .cardStyle()
    }
    private func currencyString(_ dec: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.maximumFractionDigits = 0
        return nf.string(from: NSDecimalNumber(decimal: dec)) ?? "$0"
    }
}

private struct DeltasCard: View {
    let deltas: [CategoryDelta]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes vs Previous Period").font(.title2).bold()
            VStack(spacing: 8) {
                ForEach(deltas.prefix(5), id: \.category) { delta in
                    HStack {
                        Text(delta.category.displayName)
                        Spacer()
                        let sign = delta.deltaPct >= 0 ? "+" : ""
                        let pct = String(format: "%.0f%%", delta.deltaPct * 100)
                        let color: Color = delta.deltaPct >= 0 ? .red : .green
                        Text("\(sign)\(pct)")
                            .bold()
                            .foregroundStyle(color)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(color.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct InsightsCard: View {
    let insights: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights").font(.title2).bold()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(.yellow).font(.caption)
                        Text(insight)
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct RecurringMerchantsCard: View {
    let merchants: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurring Merchants").font(.title2).bold()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(merchants.prefix(5), id: \.self) { merchant in
                    HStack {
                        Image(systemName: "repeat.circle.fill").foregroundStyle(.blue)
                        Text(merchant)
                        Spacer()
                    }
                }
            }
        }
        .cardStyle()
    }
}
