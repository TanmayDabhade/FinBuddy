//
//  DataMaintenanceService.swift
//  FinBuddy
//
//  Utilities for import/undo/reset operations and side effects.
//

import Foundation
import SwiftData

enum DataMaintenanceService {
    static let lastImportBatchKey = "lastImportBatchID"
    
    @MainActor
    static func storeLastImportBatch(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: lastImportBatchKey)
    }
    
    @MainActor
    static func undoLastImport(context: ModelContext) throws -> Int {
        guard let idString = UserDefaults.standard.string(forKey: lastImportBatchKey),
              let batchID = UUID(uuidString: idString) else { return 0 }
        let descriptor = FetchDescriptor<Expense>()
        let all = (try? context.fetch(descriptor)) ?? []
        let targets = all.filter { $0.importBatchID == batchID }
        for e in targets { context.delete(e) }
        try context.save()
        // Clear the stored batch ID after undo
        UserDefaults.standard.removeObject(forKey: lastImportBatchKey)
        return targets.count
    }
    
    @MainActor
    static func resetAllData(context: ModelContext) throws {
        // Delete all expenses and analyses
        if let exps = try? context.fetch(FetchDescriptor<Expense>()) {
            for e in exps { context.delete(e) }
        }
        if let analyses = try? context.fetch(FetchDescriptor<Analysis>()) {
            for a in analyses { context.delete(a) }
        }
        try context.save()
        UserDefaults.standard.removeObject(forKey: lastImportBatchKey)
    }
}
