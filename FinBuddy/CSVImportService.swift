// filepath: /Users/tanmay/Coding/iOS/FinBuddy/FinBuddy/CSVImportService.swift
// Lightweight CSV importer for Expenses

import Foundation
import SwiftData

struct CSVImportSummary {
    let batchID: UUID
    let inserted: Int
    let warnings: [String]
}

final class CSVImportService {
    // Expected headers (case-insensitive): title, amount, date, merchant, category, notes
    func importExpenses(from data: Data, into context: ModelContext) throws -> CSVImportSummary {
        let text = String(decoding: data, as: UTF8.self)
        let (header, rows) = try parseCSV(text)
        let lowerHeader = header.map { $0.lowercased() }

        func idx(_ key: String) -> Int? { lowerHeader.firstIndex(of: key) }

        let idxTitle = idx("title")
        let idxAmount = idx("amount")
        let idxDate = idx("date")
        let idxMerchant = idx("merchant")
        let idxCategory = idx("category")
        let idxNotes = idx("notes")

        guard let idxTitle, let idxAmount, let idxDate else {
            throw NSError(domain: "CSVImport", code: 1001, userInfo: [NSLocalizedDescriptionKey: "CSV must include title, amount, date headers."])
        }

        var warnings: [String] = []
        var inserted = 0
        let batchID = UUID()

        for (lineNo, cols) in rows.enumerated() {
            // Ensure bounds
            func col(_ i: Int?) -> String? {
                guard let i, i < cols.count else { return nil }
                let v = cols[i].trimmingCharacters(in: .whitespacesAndNewlines)
                return v.isEmpty ? nil : v
            }

            guard let title = col(idxTitle), !title.isEmpty else {
                warnings.append("Line \(lineNo + 2): missing title; skipped")
                continue
            }
            guard let amountStr = col(idxAmount), let amount = parseAmount(amountStr) else {
                warnings.append("Line \(lineNo + 2): invalid amount; skipped")
                continue
            }
            guard let dateStr = col(idxDate), let date = parseDate(dateStr) else {
                warnings.append("Line \(lineNo + 2): invalid date; skipped")
                continue
            }

            let merchant = col(idxMerchant)
            let categoryStr = col(idxCategory)
            let notes = col(idxNotes)

            let mappedCategory = Category.fromString(categoryStr)
            let uncertain = mappedCategory == nil && categoryStr != nil

            let expense = Expense(
                title: title,
                amount: amount,
                date: date,
                merchant: merchant,
                category: mappedCategory,
                source: .csvImport,
                notes: notes,
                importBatchID: batchID,
                isCategoryUncertain: uncertain
            )
            context.insert(expense)
            inserted += 1
        }

        try context.save()
        return CSVImportSummary(batchID: batchID, inserted: inserted, warnings: warnings)
    }

    // MARK: - Parsing

    private func parseCSV(_ text: String) throws -> (header: [String], rows: [[String]]) {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        var i = text.startIndex

        func endField() {
            current.append(field)
            field = ""
        }
        func endRow() {
            rows.append(current)
            current = []
        }

        while i < text.endIndex {
            let c = text[i]
            if inQuotes {
                if c == "\"" { // quote
                    let next = text.index(after: i)
                    if next < text.endIndex && text[next] == "\"" { // escaped quote
                        field.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                if c == "," {
                    endField()
                } else if c == "\n" || c == "\r" { // end of line
                    endField()
                    // Handle CRLF \r\n by looking ahead
                    let next = text.index(after: i)
                    if c == "\r" && next < text.endIndex && text[next] == "\n" { i = next }
                    endRow()
                } else if c == "\"" {
                    inQuotes = true
                } else {
                    field.append(c)
                }
            }
            i = text.index(after: i)
        }
        // Flush last field/row if present
        endField()
        if !current.isEmpty || !rows.isEmpty {
            endRow()
        }
        guard let header = rows.first else {
            throw NSError(domain: "CSVImport", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Empty CSV file."])
        }
        let dataRows = Array(rows.dropFirst()).filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        return (header, dataRows)
    }

    private func parseAmount(_ s: String) -> Decimal? {
        // Strip currency symbols and grouping
        var cleaned = s.replacingOccurrences(of: ",", with: "")
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.replacingOccurrences(of: "€", with: "")
        cleaned = cleaned.replacingOccurrences(of: "£", with: "")
        // Parentheses for negatives (e.g., (12.34))
        var negative = false
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            negative = true
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        guard var dec = Decimal(string: cleaned) else { return nil }
        if negative { dec *= -1 }
        return dec
    }

    private lazy var dateFormatters: [DateFormatter] = {
        let fmts = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy/MM/dd",
            "MMM d, yyyy",
        ]
        return fmts.map { fmt in let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = fmt; return df }
    }()

    private func parseDate(_ s: String) -> Date? {
        for df in dateFormatters { if let d = df.date(from: s) { return d } }
        return nil
    }
}
