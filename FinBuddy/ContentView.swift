//
//  ContentView.swift
//  FinBuddy
//
//  Created by Tanmay Avinash Dabhade on 10/6/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }

            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "list.bullet") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.pie") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, Analysis.self], inMemory: true)
}
