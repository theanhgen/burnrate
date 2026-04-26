import CloudKit
import Domain
import Foundation

/// Thread-safe actor wrapping CKContainer for all CloudKit sync operations.
/// Manages the custom record zone and provides read/write access to snapshots.
public actor CloudSyncContainer {
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private var zoneCreated = false

    public init(containerIdentifier: String = "iCloud.com.nguyentheanh.burnrate") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: RecordMapper.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Zone Management

    private func ensureZoneExists() async throws {
        guard !zoneCreated else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await database.save(zone)
            zoneCreated = true
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Zone already exists
            zoneCreated = true
        } catch {
            throw CloudSyncError.zoneCreationFailed(underlying: error)
        }
    }

    // MARK: - Write (macOS)

    /// Saves usage snapshots to CloudKit. Each provider gets one record, overwritten on each call.
    public func saveSnapshots(_ snapshots: [UsageSnapshot]) async throws {
        guard !snapshots.isEmpty else { return }
        try await ensureZoneExists()

        let records = try snapshots.map { try RecordMapper.record(from: $0, zoneID: zoneID) }

        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .utility

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: CloudSyncError.saveFailed(underlying: error))
                }
            }
            database.add(operation)
        }
    }

    // MARK: - Read (iOS)

    /// Fetches all usage snapshots from CloudKit.
    public func fetchAllSnapshots() async throws -> [UsageSnapshot] {
        try await ensureZoneExists()

        let query = CKQuery(
            recordType: RecordMapper.recordType,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "capturedAt", ascending: false)]

        do {
            let (results, _) = try await database.records(
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
