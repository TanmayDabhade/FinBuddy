//
//  DashboardView.swift
//  FinBuddy
//
//  Dashboard with charts and analysis visualization

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Analysis.createdAt, order: .reverse)]) private var analyses: [Analysis]
    @Query private var expenses: [Expense]

    @State private var selectedPeriodDays: Int = 7
    @State private var showAddExpense: Bool = false
    @State private var isAnalyzing: Bool = false
    @State private var importMessage: String? = nil
    @State private var showAIFallbackBanner: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Controls row
                    controls

                    if let latestAnalysis = analyses.first {
                        AnalysisChartsView(analysis: latestAnalysis)
                    } else {
                        EmptyAnalysisView(onAdd: { showAddExpense = true }, onImport: importDemoData)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddExpense = true }) {
                        Label("Log Expense", systemImage: "plus")
                    }
                    .accessibilityLabel("Log Expense")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: importDemoData) {
                        Label("Import Demo", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import Demo Data")
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
            .onChange(of: analyses.first?.id) { _ in
                // When a new analysis arrives, stop spinner
                if isAnalyzing { isAnalyzing = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiFallback)) { _ in
                showBanner()
            }
            .overlay(alignment: .top) {
                if showAIFallbackBanner {
                    Text("AI unavailable—using on-device analysis.")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.95), in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityLabel("AI fallback banner")
                }
            }
            .alert(importMessage ?? "", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Period", selection: $selectedPeriodDays) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Analysis Period")

                Spacer(minLength: 0)

                Button(action: analyze) {
                    if isAnalyzing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Analyze", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnalyzing)
                .accessibilityLabel("Analyze")
            }
        }
    }

    private func analyze() {
        isAnalyzing = true
        // Fetch fresh expenses and run analysis for selected period
        let descriptor = FetchDescriptor<Expense>()
        let allExpenses = (try? context.fetch(descriptor)) ?? expenses
        AnalysisService.shared.runAnalysis(context: context, expenses: allExpenses, periodDays: selectedPeriodDays)
    }

    private func importDemoData() {
        // Try bundled CSV first
        if let url = Bundle.main.url(forResource: "sample_expenses", withExtension: "csv"),
           let data = try? Data(contentsOf: url) {
            do {
                let summary = try CSVImportService().importExpenses(from: data, into: context)
                DataMaintenanceService.storeLastImportBatch(summary.batchID)
                importMessage = "Imported \(summary.inserted) expenses."
                // Re-run analysis after import
                let descriptor = FetchDescriptor<Expense>()
                let allExpenses = (try? context.fetch(descriptor)) ?? []
                AnalysisService.shared.runAnalysis(context: context, expenses: allExpenses, periodDays: selectedPeriodDays)
            } catch {
                importMessage = "Import failed."
            }
            return
        }
        
        // Fallback: generate demo data programmatically (if CSV missing)
        let batchID = UUID()
        let calendar = Calendar.current
        let merchants = ["Starbucks", "Amazon", "Uber", "Whole Foods", "Netflix", "Spotify", "Apple", "Target", "Shell", "Walmart"]
        let titles = ["Coffee", "Groceries", "Ride", "Subscription", "Dinner", "Fuel", "Household", "Snacks"]
        let cats: [Category] = [.food, .shopping, .transport, .entertainment, .bills, .health, .education, .other]
        let count = 40
        let today = Date()
        for _ in 0..<count {
            let daysBack = Int.random(in: 0...max(30, selectedPeriodDays * 2))
            let date = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
            let rnd = Double.random(in: 3.0...120.0)
            let amount = Decimal((rnd * 100).rounded() / 100)
            let title = titles.randomElement() ?? "Expense"
            let merchant = merchants.randomElement()
            let category = cats.randomElement() ?? .other
            let e = Expense(
                title: title,
                amount: amount,
                date: date,
                merchant: merchant,
                category: category,
                source: .csvImport,
                notes: nil,
                importBatchID: batchID,
                isCategoryUncertain: false
            )
            context.insert(e)
        }
        try? context.save()
        DataMaintenanceService.storeLastImportBatch(batchID)
        importMessage = "Demo data added."
        // Analyze after generating demo
        let descriptor = FetchDescriptor<Expense>()
        let allExpenses = (try? context.fetch(descriptor)) ?? []
        AnalysisService.shared.runAnalysis(context: context, expenses: allExpenses, periodDays: selectedPeriodDays)
    }
    
    private func showBanner() {
        withAnimation { showAIFallbackBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showAIFallbackBanner = false }
        }
    }
}

// MARK: - Analysis Charts View
private struct AnalysisChartsView: View {
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
    }
}

// MARK: - Summary Card
private struct SummaryCard: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Period Summary")
                .font(.title2)
                .bold()
            
            Text(analysis.summary)
                .font(.body)
                .foregroundStyle(.secondary)
            
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

// MARK: - Category Bar Chart
private struct CategoryBarChart: View {
    let topCategories: [CategoryTotal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories")
                .font(.title2)
                .bold()
            
            if topCategories.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(topCategories, id: \.category) { item in
                    BarMark(
                        x: .value("Amount", NSDecimalNumber(decimal: item.total).doubleValue),
                        y: .value("Category", item.category.displayName)
                    )
                    .foregroundStyle(by: .value("Category", item.category.displayName))
                }
                .frame(height: CGFloat(max(200, topCategories.count * 40)))
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Category Pie Chart
private struct CategoryPieChart: View {
    let topCategories: [CategoryTotal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Distribution")
                .font(.title2)
                .bold()
            
            if topCategories.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 250)
                .chartLegend(position: .bottom, alignment: .center)
            }
        }
        .cardStyle()
    }
    
    private func currencyString(_ dec: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 0
        return nf.string(from: NSDecimalNumber(decimal: dec)) ?? "$0"
    }
}

// MARK: - Deltas Card
private struct DeltasCard: View {
    let deltas: [CategoryDelta]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes vs Previous Period")
                .font(.title2)
                .bold()
            
            VStack(spacing: 8) {
                ForEach(deltas.prefix(5), id: \.category) { delta in
                    HStack {
                        Text(delta.category.displayName)
                            .font(.body)
                        
                        Spacer()
                        
                        let sign = delta.deltaPct >= 0 ? "+" : ""
                        let pct = String(format: "%.0f%%", delta.deltaPct * 100)
                        let color: Color = delta.deltaPct >= 0 ? .red : .green
                        
                        Text("\(sign)\(pct)")
                            .font(.body)
                            .bold()
                            .foregroundStyle(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Insights Card
private struct InsightsCard: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(insight)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Recurring Merchants Card
private struct RecurringMerchantsCard: View {
    let merchants: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurring Merchants")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(merchants.prefix(5), id: \.self) { merchant in
                    HStack {
                        Image(systemName: "repeat.circle.fill")
                            .foregroundStyle(.blue)
                        Text(merchant)
                            .font(.body)
                        Spacer()
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Empty Analysis View
private struct EmptyAnalysisView: View {
    var onAdd: () -> Void
    var onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Analysis Yet")
                .font(.title2)
                .bold()
            
            Text("Import sample data or add one to begin.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: onImport) {
                    Label("Import Sample Data", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Button(action: onAdd) {
                    Label("Add Expense", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
