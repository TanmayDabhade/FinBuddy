// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/Theme.swift
// Lightweight design system: card style and category visuals

import SwiftUI

// Reusable card container style used across the app
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// Visuals for categories
extension Category {
    var color: Color {
        switch self {
        case .food: return .orange
        case .transport: return .teal
        case .shopping: return .pink
        case .bills: return .indigo
        case .entertainment: return .purple
        case .health: return .green
        case .education: return .blue
        case .rent: return .brown
        case .other: return .gray
        }
    }

    var symbolName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car"
        case .shopping: return "bag"
        case .bills: return "doc.text"
        case .entertainment: return "gamecontroller"
        case .health: return "cross.case"
        case .education: return "book"
        case .rent: return "house"
        case .other: return "circle.grid.2x2"
        }
    }
}
