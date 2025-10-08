// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/SettingsView.swift
// Minimal settings screen scaffold per PRD

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("currencyCode") private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("useAIAnalysis") private var useAIAnalysis: Bool = true

    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var confirmReset: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Picker("Currency", selection: $currencyCode) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("INR").tag("INR")
                        Text("GBP").tag("GBP")
                    }
                }
                Section("Analysis") {
                    Toggle("Use AI for analysis", isOn: $useAIAnalysis)
                }
                Section("Data") {
                    Button { importDemo() } label: {
                        Label("Import Demo Data", systemImage: "square.and.arrow.down")
                    }
                    Button { undoImport() } label: {
                        Label("Undo Last Import", systemImage: "arrow.uturn.backward")
                    }
                    Button(role: .destructive) { confirmReset = true } label: {
                        Label("Reset App Data", systemImage: "trash")
                    }
                }
                Section(footer: Text("Privacy: No bank connections. Data stays local to your device. Demo CSV import only.")) {
                    Text("Version 0.1.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(alertMessage) }
            .alert("Reset App Data?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetAll() }
            } message: {
                Text("This permanently deletes expenses and analyses.")
            }
        }
    }

    private func importDemo() {
        if let url = Bundle.main.url(forResource: "sample_expenses", withExtension: "csv"),
           let data = try? Data(contentsOf: url) {
            do {
                let summary = try CSVImportService().importExpenses(from: data, into: context)
                DataMaintenanceService.storeLastImportBatch(summary.batchID)
                alertTitle = "Import"
                alertMessage = "Imported \(summary.inserted) expenses."
                showAlert = true
                // Re-run analysis
                let all = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
                AnalysisService.shared.runAutoAnalysis(context: context, expenses: all)
            } catch {
                alertTitle = "Import Failed"
                alertMessage = error.localizedDescription
                showAlert = true
            }
            return
        }
        alertTitle = "Import"
        alertMessage = "Bundled sample file not found."
        showAlert = true
    }

    private func undoImport() {
        do {
            let removed = try DataMaintenanceService.undoLastImport(context: context)
            alertTitle = "Undo Import"
            alertMessage = removed > 0 ? "Removed \(removed) expenses from last batch." : "No recent import batch found."
            showAlert = true
            let all = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
            AnalysisService.shared.runAutoAnalysis(context: context, expenses: all)
        } catch {
            alertTitle = "Undo Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func resetAll() {
        do {
            try DataMaintenanceService.resetAllData(context: context)
            alertTitle = "Reset"
            alertMessage = "All app data cleared."
            showAlert = true
        } catch {
            alertTitle = "Reset Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
