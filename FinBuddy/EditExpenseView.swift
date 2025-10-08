//
//  EditExpenseView.swift
//  FinBuddy
//
//  Edit existing expense with manual category override.
//

import SwiftUI
import SwiftData

struct EditExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var expense: Expense

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
            .navigationTitle("Edit Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        title = expense.title
        amountString = NSDecimalNumber(decimal: expense.amount).stringValue
        date = expense.date
        merchant = expense.merchant ?? ""
        category = expense.category ?? .other
        notes = expense.notes ?? ""
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Decimal(string: amountString) != nil
    }

    private func save() {
        guard let amount = Decimal(string: amountString) else { return }
        expense.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.amount = amount
        expense.date = date
        expense.merchant = merchant.isEmpty ? nil : merchant
        // Manual override wins
        expense.category = category
        expense.isCategoryUncertain = false
        expense.notes = notes.isEmpty ? nil : notes
        try? context.save()
        
        // Re-run auto analysis
        let descriptor = FetchDescriptor<Expense>()
        let allExpenses = (try? context.fetch(descriptor)) ?? []
        AnalysisService.shared.runAutoAnalysis(context: context, expenses: allExpenses)
        
        dismiss()
    }
}
