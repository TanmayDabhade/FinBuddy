// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/AddExpenseView.swift
// Simple add expense form

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]

    @State private var title: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = .now
    @State private var merchant: String = ""
    @State private var category: Category = .other
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Merchant (optional)", text: $merchant)
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Decimal(string: amountString) != nil
    }

    private func save() {
        guard let amount = Decimal(string: amountString) else { return }
        let exp = Expense(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            date: date,
            merchant: merchant.isEmpty ? nil : merchant,
            category: category,
            source: .manual,
            notes: notes.isEmpty ? nil : notes
        )
        context.insert(exp)
        try? context.save()
        
        // Fetch fresh expenses from database and run analysis
        let descriptor = FetchDescriptor<Expense>()
        let allExpenses = (try? context.fetch(descriptor)) ?? []
        AnalysisService.shared.runAutoAnalysis(context: context, expenses: allExpenses)
        
        dismiss()
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
