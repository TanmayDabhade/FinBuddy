// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/ExpensesView.swift
// Minimal expenses list scaffold per PRD with filters and editing

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var showingAdd = false
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var searchText: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var editingExpense: Expense? = nil

    private var filteredExpenses: [Expense] {
        let base = expenses
        let byCategory = selectedCategory == nil ? base : base.filter { $0.category == selectedCategory }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return byCategory }
        let q = searchText.lowercased()
        return byCategory.filter { e in
            let inTitle = e.title.lowercased().contains(q)
            let inMerchant = (e.merchant ?? "").lowercased().contains(q)
            let inCategory = e.category?.displayName.lowercased().contains(q) ?? false
            return inTitle || inMerchant || inCategory
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "No expenses yet",
                        systemImage: "tray",
                        description: Text("Import sample data or add one to begin.")
                    )
                } else {
                    VStack(spacing: 8) {
                        categoryChips
                        List {
                            ForEach(filteredExpenses) { exp in
                                ExpenseRow(expense: exp)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingExpense = exp }
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showingImporter = true } label: { Image(systemName: "tray.and.arrow.down") }
                        .accessibilityLabel("Import CSV")
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add expense")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(isPresented: $showingAdd) { AddExpenseView() }
            .sheet(item: $editingExpense) { exp in
                EditExpenseView(expense: exp)
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [UTType.commaSeparatedText, .text]) { result in
                switch result {
                case .success(let url):
                    do {
                        let data = try Data(contentsOf: url)
                        let summary = try CSVImportService().importExpenses(from: data, into: context)
                        DataMaintenanceService.storeLastImportBatch(summary.batchID)
                        let warnCount = summary.warnings.count
                        alertMessage = "Imported \(summary.inserted) expenses.\(warnCount > 0 ? " Warnings: \(warnCount)." : "")"
                        
                        // Fetch fresh expenses from database and run analysis
                        let descriptor = FetchDescriptor<Expense>()
                        let allExpenses = (try? context.fetch(descriptor)) ?? []
                        AnalysisService.shared.runAutoAnalysis(context: context, expenses: allExpenses)
                    } catch {
                        alertMessage = "Import failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    alertMessage = "Import canceled: \(error.localizedDescription)"
                }
            }
            .alert("Import", isPresented: .constant(alertMessage != nil), actions: {
                Button("OK") { alertMessage = nil }
            }, message: {
                Text(alertMessage ?? "")
            })
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(Category.allCases) { c in
                    chip(title: c.displayName, isSelected: selectedCategory == c) { selectedCategory = c }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter: \(title)")
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { filteredExpenses[$0] }
        for item in items { context.delete(item) }
        try? context.save()
        
        // Fetch fresh expenses from database and run analysis
        let descriptor = FetchDescriptor<Expense>()
        let allExpenses = (try? context.fetch(descriptor)) ?? []
        AnalysisService.shared.runAutoAnalysis(context: context, expenses: allExpenses)
    }
}

#Preview {
    ExpensesView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
