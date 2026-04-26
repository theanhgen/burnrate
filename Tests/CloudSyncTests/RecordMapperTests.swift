import Testing
import Foundation
import CloudKit
@testable import Domain
@testable import CloudSync

@Suite("RecordMapper Tests")
struct RecordMapperTests {

    private let zoneID = CKRecordZone.ID(
        zoneName: RecordMapper.zoneName,
        ownerName: CKCurrentUserDefaultName
    )

    // MARK: - Record ID Tests

    @Test
    func `recordID includes provider id`() {
        let id = RecordMapper.recordID(for: "claude", zoneID: zoneID)
        #expect(id.recordName == "snapshot-claude")
    }

    @Test
    func `recordID uses provided zone`() {
        let id = RecordMapper.recordID(for: "codex", zoneID: zoneID)
        #expect(id.zoneID == zoneID)
    }

    // MARK: - Domain to CKRecord Tests

    @Test
    func `record from snapshot sets providerId`() throws {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 90, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        )

        let record = try RecordMapper.record(from: snapshot, zoneID: zoneID)

        #expect(record["providerId"] as? String == "claude")
    }

    @Test
    func `record from snapshot sets capturedAt`() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 90, quotaType: .session, providerId: "claude")],
            capturedAt: date
        )

        let record = try RecordMapper.record(from: snapshot, zoneID: zoneID)

        #expect(record["capturedAt"] as? Date == date)
    }

    @Test
    func `record from snapshot includes quotasJSON`() throws {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 75, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        )

        let record = try RecordMapper.record(from: snapshot, zoneID: zoneID)

        #expect(record["quotasJSON"] as? Data != nil)
    }

    @Test
    func `record from snapshot includes optional accountEmail`() throws {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 90, quotaType: .session, providerId: "claude")],
            capturedAt: Date(),
            accountEmail: "user@example.com"
        )

        let record = try RecordMapper.record(from: snapshot, zoneID: zoneID)

        #expect(record["accountEmail"] as? String == "user@example.com")
    }

    @Test
    func `record from snapshot has correct record type`() throws {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        )

        let record = try RecordMapper.record(from: snapshot, zoneID: zoneID)

        #expect(record.recordType == RecordMapper.recordType)
    }

    // MARK: - Round-Trip Tests

    @Test
    func `snapshot survives round trip through CKRecord`() throws {
        let original = UsageSnapshot(
            providerId: "gemini",
            quotas: [
                UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "gemini", resetText: "Resets hourly")
            ],
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            accountEmail: "test@example.com"
        )

        let record = try RecordMapper.record(from: original, zoneID: zoneID)
        let restored = try RecordMapper.snapshot(from: record)

        #expect(restored.providerId == original.providerId)
        #expect(restored.quotas.count == original.quotas.count)
        #expect(restored.quotas.first?.percentRemaining == 80)
        #expect(restored.accountEmail == "test@example.com")
    }

    // MARK: - Invalid Record Tests

    @Test
    func `snapshot from record throws for missing providerId`() {
        let record = CKRecord(recordType: RecordMapper.recordType)
        record["capturedAt"] = Date() as CKRecordValue
        record["quotasJSON"] = Data() as CKRecordValue

        #expect(throws: CloudSyncError.self) {
            try RecordMapper.snapshot(from: record)
        }
    }

    @Test
    func `snapshot from record throws for missing capturedAt`() {
        let record = CKRecord(recordType: RecordMapper.recordType)
        record["providerId"] = "claude" as CKRecordValue
        record["quotasJSON"] = Data() as CKRecordValue

        #expect(throws: CloudSyncError.self) {
            try RecordMapper.snapshot(from: record)
        }
    }

    @Test
    func `snapshot from record throws for missing quotasJSON`() {
        let record = CKRecord(recordType: RecordMapper.recordType)
        record["providerId"] = "claude" as CKRecordValue
        record["capturedAt"] = Date() as CKRecordValue

        #expect(throws: CloudSyncError.self) {
            try RecordMapper.snapshot(from: record)
        }
    }
}
