import Foundation
import SwiftData
import CloudKit
import os

@MainActor
final class CloudKitSyncEngine {

    enum SyncError: Error {
        case notReady
    }

    private let database: CKDatabase
    private let modelContext: ModelContext
    private let userID: String

    private let defaults: UserDefaults

    private var isSyncing = false

    init?(modelContext: ModelContext, userID: String) {
        guard let db = CloudKitManager.shared.privateDatabase() else {
            Log.sync.warning("CloudKitSyncEngine: CloudKit unavailable, sync disabled")
            return nil
        }
        self.database = db
        self.modelContext = modelContext
        self.userID = userID
        self.defaults = UserDefaults(suiteName: AppGroupID.suiteName) ?? .standard
    }

    private var lastSyncKey: String { "cloudkit.lastSync.\(userID)" }

    private var lastMemoryUploadKey: String { "cloudkit.lastMemoryUpload.\(userID)" }

    private var lastMemoryUploadAt: Date {
        get { (defaults.object(forKey: lastMemoryUploadKey) as? Date) ?? .distantPast }
        set { defaults.set(newValue, forKey: lastMemoryUploadKey) }
    }

    private var lastSyncDate: Date {
        get { (defaults.object(forKey: lastSyncKey) as? Date) ?? .distantPast }
        set { defaults.set(newValue, forKey: lastSyncKey) }
    }

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // 1) Pull remote changes
            try await pullRemoteTasks()
            try await pullRemoteMemory()

            // 2) Push local changes
            try await pushLocalTasks()
            try await pushLocalMemory()

            lastSyncDate = Date()
        } catch {
            Log.sync.error("CloudKit sync failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Tasks

    private func pullRemoteTasks() async throws {
        let since = lastSyncDate
        let predicate = NSPredicate(format: "updatedAt > %@", since as NSDate)
        let query = CKQuery(recordType: "Task", predicate: predicate)

        let records = try await fetchAllRecords(query: query, zoneID: nil, limit: 200)

        for record in records {
            guard let uuid = UUID(uuidString: record.recordID.recordName) else { continue }

            let remoteUpdatedAt = (record["updatedAt"] as? Date) ?? record.modificationDate ?? .distantPast

            // Fetch local item
            let descriptor = FetchDescriptor<NudgeItem>(
                predicate: #Predicate { $0.id == uuid },
                sortBy: []
            )
            let locals = try modelContext.fetch(descriptor)
            if let local = locals.first {
                if local.updatedAt >= remoteUpdatedAt { continue }
                apply(record: record, to: local)
            } else {
                let item = makeLocalItem(from: record, id: uuid)
                modelContext.insert(item)
            }
        }

        try? modelContext.save() // Best-effort — remote sync is non-critical
    }

    private func pushLocalTasks() async throws {
        let since = lastSyncDate
        let descriptor = FetchDescriptor<NudgeItem>(predicate: #Predicate { $0.updatedAt > since })
        let changed = (try? modelContext.fetch(descriptor)) ?? []
        guard !changed.isEmpty else { return }

        let records = changed.map { makeRecord(from: $0) }
        _ = try await modify(recordsToSave: records, recordIDsToDelete: [])
    }

    private func makeRecord(from item: NudgeItem) -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.id.uuidString)
        let record = CKRecord(recordType: "Task", recordID: recordID)

        record["content"] = item.content as CKRecordValue
        record["emoji"] = item.emoji as CKRecordValue?
        record["sourceTypeRaw"] = item.sourceTypeRaw as CKRecordValue
        record["sourceUrl"] = item.sourceUrl as CKRecordValue?
        record["sourcePreview"] = item.sourcePreview as CKRecordValue?
        record["statusRaw"] = item.statusRaw as CKRecordValue
        record["snoozedUntil"] = item.snoozedUntil as CKRecordValue?
        record["dueDate"] = item.dueDate as CKRecordValue?
        record["priorityRaw"] = item.priorityRaw as CKRecordValue?
        record["createdAt"] = item.createdAt as CKRecordValue
        record["updatedAt"] = item.updatedAt as CKRecordValue
        record["completedAt"] = item.completedAt as CKRecordValue?
        record["sortOrder"] = item.sortOrder as CKRecordValue
        record["actionTypeRaw"] = item.actionTypeRaw as CKRecordValue?
        record["actionTarget"] = item.actionTarget as CKRecordValue?
        record["contactName"] = item.contactName as CKRecordValue?
        record["aiDraft"] = item.aiDraft as CKRecordValue?
        record["aiDraftSubject"] = item.aiDraftSubject as CKRecordValue?
        record["draftGeneratedAt"] = item.draftGeneratedAt as CKRecordValue?
        
        // Phase 10: Sync category data across devices
        record["categoryRaw"] = item.categoryRaw as CKRecordValue?
        record["categoryColorHex"] = item.categoryColorHex as CKRecordValue?
        record["categoryIcon"] = item.categoryIcon as CKRecordValue?

        return record
    }

    private func makeLocalItem(from record: CKRecord, id: UUID) -> NudgeItem {
        let content = (record["content"] as? String) ?? ""
        let sourceTypeRaw = (record["sourceTypeRaw"] as? String) ?? SourceType.manual.rawValue
        let sourceType = SourceType(rawValue: sourceTypeRaw) ?? .manual

        let item = NudgeItem(
            id: id,
            content: content,
            sourceType: sourceType,
            sourceUrl: record["sourceUrl"] as? String,
            sourcePreview: record["sourcePreview"] as? String,
            emoji: record["emoji"] as? String,
            actionType: (record["actionTypeRaw"] as? String).flatMap(ActionType.init(rawValue:)),
            actionTarget: record["actionTarget"] as? String,
            contactName: record["contactName"] as? String,
            sortOrder: record["sortOrder"] as? Int ?? 0,
            priority: (record["priorityRaw"] as? String).flatMap(TaskPriority.init(rawValue:)),
            dueDate: record["dueDate"] as? Date,
            category: (record["categoryRaw"] as? String).flatMap(TaskCategory.init(rawValue:))
        )

        apply(record: record, to: item)
        return item
    }

    private func apply(record: CKRecord, to item: NudgeItem) {
        item.content = (record["content"] as? String) ?? item.content
        item.emoji = record["emoji"] as? String
        item.sourceTypeRaw = (record["sourceTypeRaw"] as? String) ?? item.sourceTypeRaw
        item.sourceUrl = record["sourceUrl"] as? String
        item.sourcePreview = record["sourcePreview"] as? String
        item.statusRaw = (record["statusRaw"] as? String) ?? item.statusRaw
        item.snoozedUntil = record["snoozedUntil"] as? Date
        item.dueDate = record["dueDate"] as? Date
        item.priorityRaw = record["priorityRaw"] as? String
        item.completedAt = record["completedAt"] as? Date
        item.sortOrder = record["sortOrder"] as? Int ?? item.sortOrder
        item.actionTypeRaw = record["actionTypeRaw"] as? String
        item.actionTarget = record["actionTarget"] as? String
        item.contactName = record["contactName"] as? String
        item.aiDraft = record["aiDraft"] as? String
        item.aiDraftSubject = record["aiDraftSubject"] as? String
        item.draftGeneratedAt = record["draftGeneratedAt"] as? Date
        
        // Phase 10: Sync category across devices
        item.categoryRaw = record["categoryRaw"] as? String
        item.categoryColorHex = record["categoryColorHex"] as? String
        item.categoryIcon = record["categoryIcon"] as? String

        let remoteUpdatedAt = (record["updatedAt"] as? Date) ?? record.modificationDate ?? item.updatedAt
        item.updatedAt = remoteUpdatedAt
    }

    // MARK: - Memory

    private func pullRemoteMemory() async throws {
        let recordID = CKRecord.ID(recordName: "NudgyMemory")
        do {
            let record = try await database.record(for: recordID)
            guard let jsonString = record["storeJSON"] as? String,
                  let data = jsonString.data(using: .utf8),
                  let store = try? JSONDecoder().decode(NudgyMemoryStore.self, from: data) else {
                return
            }
            NudgyMemory.shared.replaceStore(store)
        } catch let error as CKError where error.code == .unknownItem {
            // No remote memory yet — first sync
        } catch {
            Log.sync.warning("CloudKit pullRemoteMemory failed: \(error, privacy: .public)")
        }
    }

    private func pushLocalMemory() async throws {
        // Throttle memory uploads (memory can save frequently).
        let now = Date()
        if now.timeIntervalSince(lastMemoryUploadAt) < 10 {
            return
        }
        try await upsertMemoryRecord()
        lastMemoryUploadAt = now
    }

    private func upsertMemoryRecord() async throws {
        guard let data = NudgyMemory.shared.exportJSON(),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        let recordID = CKRecord.ID(recordName: "NudgyMemory")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "NudgyMemory", recordID: recordID)
        }

        record["storeJSON"] = jsonString as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    // MARK: - CloudKit helpers

    private func fetchAllRecords(query: CKQuery, zoneID: CKRecordZone.ID?, limit: Int) async throws -> [CKRecord] {
        var results: [CKRecord] = []

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = limit
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    results.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: results)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID]) async throws -> (saved: [CKRecord], deleted: [CKRecord.ID]) {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
            op.savePolicy = .changedKeys
            op.isAtomic = false
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (recordsToSave, recordIDsToDelete))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }
}

private extension CKDatabase {
    func record(for id: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            fetch(withRecordID: id) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let record else {
                    continuation.resume(throwing: CKError(.unknownItem))
                    return
                }
                continuation.resume(returning: record)
            }
        }
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: saved ?? record)
            }
        }
    }
}
