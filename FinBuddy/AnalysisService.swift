//
//  AnalysisService.swift
//  FinBuddy
//
//  Service to automatically run analysis when expenses change

import Foundation
import SwiftData

extension Notification.Name {
    static let aiFallback = Notification.Name("AIAnalysisFallbackNotification")
}

@MainActor
class AnalysisService {
    static let shared = AnalysisService()
    
    private init() {}
    
    /// Automatically runs analysis for the last 7 days vs previous 7 days
    func runAutoAnalysis(context: ModelContext, expenses: [Expense]) {
        Task {
            // Delete all existing analyses to prevent duplication
            let descriptor = FetchDescriptor<Analysis>()
            if let existingAnalyses = try? context.fetch(descriptor) {
                for analysis in existingAnalyses {
                    context.delete(analysis)
                }
            }
            
            // Define period: last 7 days
            let now = Date()
            let calendar = Calendar.current
            guard let periodStart = calendar.date(byAdding: .day, value: -7, to: now) else { return }
            let periodEnd = now
            
            // Previous period: 7 days before that
            guard let prevPeriodStart = calendar.date(byAdding: .day, value: -14, to: now),
                  let prevPeriodEnd = calendar.date(byAdding: .day, value: -7, to: now) else { return }
            
            // Filter expenses for current period
            let currentExpenses = expenses.filter { $0.date >= periodStart && $0.date <= periodEnd }
            
            // Filter expenses for previous period
            let previousExpenses = expenses.filter { $0.date >= prevPeriodStart && $0.date <= prevPeriodEnd }
            
            // Get basic analysis from InsightsEngine
            let basicAnalysis = InsightsEngine.analyze(
                expenses: currentExpenses,
                prevExpenses: previousExpenses,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
            
            // Respect AI toggle
            let useAI = UserDefaults.standard.bool(forKey: "useAIAnalysis")
            guard useAI else {
                context.insert(basicAnalysis)
                try? context.save()
                return
            }
            
            // 🤖 Try AI-powered insights
            let totalSpending = currentExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            let previousSpending = previousExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            
            let aiContext = AIAnalysisService.AnalysisContext(
                totalSpending: totalSpending,
                topCategories: basicAnalysis.topCategories,
                deltas: basicAnalysis.deltas,
                recurringMerchants: basicAnalysis.recurringMerchants,
                periodStart: periodStart,
                periodEnd: periodEnd,
                previousPeriodSpending: previousSpending
            )
            
            do {
                // Try to get AI-powered insights (with internal single retry on parse/API errors)
                let aiResult = try await AIAnalysisService.shared.generateInsights(context: aiContext)
                
                // Create analysis with AI insights
                let analysis = Analysis(
                    periodStart: periodStart,
                    periodEnd: periodEnd,
                    topCategories: basicAnalysis.topCategories,
                    deltas: basicAnalysis.deltas,
                    recurringMerchants: basicAnalysis.recurringMerchants,
                    insights: aiResult.insights + aiResult.recommendations,
                    summary: aiResult.summary
                )
                
                context.insert(analysis)
                try? context.save()
            } catch {
                // Fallback to rule-based insights if AI fails
                NotificationCenter.default.post(name: .aiFallback, object: nil)
                context.insert(basicAnalysis)
                try? context.save()
            }
        }
    }

    /// Run a manual analysis for the last `periodDays` days vs previous equal window. Does not delete existing history.
    func runAnalysis(context: ModelContext, expenses: [Expense], periodDays: Int) {
        Task {
            let now = Date()
            let calendar = Calendar.current
            guard let periodStart = calendar.date(byAdding: .day, value: -abs(periodDays), to: now) else { return }
            let periodEnd = now
            
            guard let prevPeriodEnd = calendar.date(byAdding: .day, value: -abs(periodDays), to: now),
                  let prevPeriodStart = calendar.date(byAdding: .day, value: -2 * abs(periodDays), to: now) else { return }
            
            let currentExpenses = expenses.filter { $0.date >= periodStart && $0.date <= periodEnd }
            let previousExpenses = expenses.filter { $0.date >= prevPeriodStart && $0.date <= prevPeriodEnd }
            
            let basicAnalysis = InsightsEngine.analyze(
                expenses: currentExpenses,
                prevExpenses: previousExpenses,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
            
            // Respect AI toggle
            let useAI = UserDefaults.standard.bool(forKey: "useAIAnalysis")
            guard useAI else {
                context.insert(basicAnalysis)
                try? context.save()
                return
            }
            
            let totalSpending = currentExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            let previousSpending = previousExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            
            let aiContext = AIAnalysisService.AnalysisContext(
                totalSpending: totalSpending,
                topCategories: basicAnalysis.topCategories,
                deltas: basicAnalysis.deltas,
                recurringMerchants: basicAnalysis.recurringMerchants,
                periodStart: periodStart,
                periodEnd: periodEnd,
                previousPeriodSpending: previousSpending
            )
            
            do {
                let aiResult = try await AIAnalysisService.shared.generateInsights(context: aiContext)
                let analysis = Analysis(
                    periodStart: periodStart,
                    periodEnd: periodEnd,
                    topCategories: basicAnalysis.topCategories,
                    deltas: basicAnalysis.deltas,
                    recurringMerchants: basicAnalysis.recurringMerchants,
                    insights: aiResult.insights + aiResult.recommendations,
                    summary: aiResult.summary
                )
                context.insert(analysis)
                try? context.save()
            } catch {
                NotificationCenter.default.post(name: .aiFallback, object: nil)
                context.insert(basicAnalysis)
                try? context.save()
            }
        }
    }
}
