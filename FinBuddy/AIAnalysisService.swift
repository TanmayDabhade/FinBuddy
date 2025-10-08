//
//  AIAnalysisService.swift
//  FinBuddy
//
//  AI-powered expense analysis using LLM for human-like insights.

import Foundation

final class AIAnalysisService {
    static let shared = AIAnalysisService()
    
    private let apiKey: String
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {
        // Read from environment; do NOT hardcode secrets.
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    
    struct AnalysisContext {
        let totalSpending: Decimal
        let topCategories: [CategoryTotal]
        let deltas: [CategoryDelta]
        let recurringMerchants: [String]
        let periodStart: Date
        let periodEnd: Date
        let previousPeriodSpending: Decimal
    }
    
    func generateInsights(context: AnalysisContext) async throws -> AnalysisResult {
        guard !apiKey.isEmpty else {
            throw AIAnalysisError.missingAPIKey
        }
        
        // First attempt
        do {
            return try await requestInsights(context: context, retryHint: nil)
        } catch AIAnalysisError.parseError {
            // Single retry with explicit JSON reminder
            return try await requestInsights(context: context, retryHint: "Return valid JSON that matches the schema exactly. No extra keys.")
        } catch AIAnalysisError.apiError {
            // Single retry on transient API errors
            return try await requestInsights(context: context, retryHint: nil)
        }
    }
    
    private func requestInsights(context: AnalysisContext, retryHint: String?) async throws -> AnalysisResult {
        let prompt = buildAnalysisPrompt(context: context) + (retryHint != nil ? "\n\n" + (retryHint ?? "") : "")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 800,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIAnalysisError.apiError
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw AIAnalysisError.parseError
        }
        
        guard let contentData = content.data(using: .utf8) else { throw AIAnalysisError.parseError }
        return try JSONDecoder().decode(AnalysisResult.self, from: contentData)
    }
    
    private var systemPrompt: String {
        """
        You are a friendly, knowledgeable personal finance advisor analyzing a user's spending patterns.
        
        Your goal is to:
        1. Provide actionable, personalized insights about their spending
        2. Identify patterns, trends, and potential savings opportunities
        3. Offer encouragement and practical advice
        4. Be conversational and empathetic, not judgmental
        5. Focus on specific categories and amounts
        
        Always respond in valid JSON format with this structure:
        {
          "summary": "Brief 1-2 sentence overview of their spending period",
          "insights": ["insight1", "insight2", "insight3"],
          "recommendations": ["rec1", "rec2"],
          "tone": "positive|neutral|cautionary"
        }
        
        Keep insights concise (1-2 sentences each), specific, and actionable.
        """
    }
    
    private func buildAnalysisPrompt(context: AnalysisContext) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let periodStart = dateFormatter.string(from: context.periodStart)
        let periodEnd = dateFormatter.string(from: context.periodEnd)
        
        let categoryBreakdown = context.topCategories
            .map { "• \($0.category.displayName): $\(formatDecimal($0.total))" }
            .joined(separator: "\n")
        
        let changes = context.deltas
            .map { "• \($0.category.displayName): \($0.deltaPct > 0 ? "+" : "")\(String(format: "%.1f", $0.deltaPct * 100))%" }
            .joined(separator: "\n")
        
        let merchants = context.recurringMerchants.isEmpty ? "None detected" : context.recurringMerchants.joined(separator: ", ")
        
        let spendingChange = context.totalSpending - context.previousPeriodSpending
        let spendingChangePct = context.previousPeriodSpending > 0 
            ? (NSDecimalNumber(decimal: spendingChange).doubleValue / NSDecimalNumber(decimal: context.previousPeriodSpending).doubleValue) * 100 
            : 0
        
        return """
        Analyze this user's spending for the period \(periodStart) to \(periodEnd):
        
        TOTAL SPENDING: $\(formatDecimal(context.totalSpending))
        Previous period: $\(formatDecimal(context.previousPeriodSpending))
        Change: \(spendingChange > 0 ? "+$" : "-$")\(formatDecimal(abs(spendingChange))) (\(String(format: "%.1f", spendingChangePct))%)
        
        TOP SPENDING CATEGORIES:
        \(categoryBreakdown)
        
        CHANGES VS PREVIOUS PERIOD:
        \(changes)
        
        RECURRING MERCHANTS:
        \(merchants)
        
        Provide personalized insights, identify patterns, suggest savings opportunities, and offer encouragement.
        """
    }
    
    private func formatDecimal(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "0.00"
    }
}

struct AnalysisResult: Codable {
    let summary: String
    let insights: [String]
    let recommendations: [String]
    let tone: String
}

enum AIAnalysisError: Error {
    case apiError
    case parseError
    case missingAPIKey
}

// OpenAI API response models
private struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}
