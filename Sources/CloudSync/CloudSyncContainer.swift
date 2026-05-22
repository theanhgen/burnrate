import CloudKit
import Domain
import Foundation

/// Thread-safe actor wrapping CKContainer for all CloudKit sync operations.
/// Manages the custom record zone and provides read/write access to snapshots.
public actor CloudSyncContainer {
    private let containerIdentifier: String
    private var _container: CKContainer?
    private var _database: CKDatabase?
    private var _zoneID: CKRecordZone.ID?
    private var zoneCreated = false

    public init(containerIdentifier: String = "iCloud.com.nguyentheanh.burnrate") {
        self.containerIdentifier = containerIdentifier
    }

    // Lazily resolved on first async use — never called at init time
    private func ckDatabase() -> CKDatabase {
        if _database == nil {
            let c = CKContainer(identifier: containerIdentifier)
            _container = c
            _database = c.privateCloudDatabase
        }
        return _database!
    }

    private func ckZoneID() -> CKRecordZone.ID {
        if _zoneID == nil {
            _zoneID = CKRecordZone.ID(zoneName: RecordMapper.zoneName, ownerName: CKCurrentUserDefaultName)
        }
        return _zoneID!
    }

    // MARK: - Zone Management

    private func ensureZoneExists() async throws {
        guard !zoneCreated else { return }
        let db = ckDatabase()
        let zone = CKRecordZone(zoneID: ckZoneID())
        do {
            _ = try await db.save(zone)
            zoneCreated = true
        } catch let error as CKError where error.code == .serverRejectedRequest {
            zoneCreated = true
        } catch let error as CKError where error.code == .notAuthenticated {
            throw CloudSyncError.noAccount
        } catch {
            throw CloudSyncError.zoneCreationFailed(underlying: error)
        }
    }

    // MARK: - Write (macOS)

    public func saveSnapshots(_ snapshots: [UsageSnapshot]) async throws {
        guard !snapshots.isEmpty else { return }
        try await ensureZoneExists()

        let zoneID = ckZoneID()
        let records = try snapshots.map { try RecordMapper.record(from: $0, zoneID: zoneID) }

        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .utility

        let db = ckDatabase()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: CloudSyncError.saveFailed(underlying: error))
                }
            }
            db.add(operation)
        }
    }

    // MARK: - Read (iOS)

    public func fetchAllSnapshots() async throws -> [UsageSnapshot] {
        try await ensureZoneExists()

        let db = ckDatabase()
        let zoneID = ckZoneID()
        let query = CKQuery(
            recordType: RecordMapper.recordType,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "capturedAt", ascending: false)]

        do {
            let (results, _) = try await db.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 50
            )

            return results.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return try? RecordMapper.snapshot(from: record)
            }
        } catch {
            throw CloudSyncError.fetchFailed(underlying: error)
        }
    }
}
