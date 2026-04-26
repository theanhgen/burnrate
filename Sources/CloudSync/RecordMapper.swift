import CloudKit
import Domain
import Foundation

/// Maps between UsageSnapshot domain objects and CKRecord instances.
enum RecordMapper {
    static let recordType = "UsageSnapshot"
    static let zoneName = "BurnrateZone"

    /// Creates a CKRecord.ID for a provider snapshot.
    static func recordID(for providerId: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "snapshot-\(providerId)", zoneID: zoneID)
    }

    // MARK: - Domain → CKRecord

    /// Converts a UsageSnapshot into a CKRecord for CloudKit storage.
    static func record(
        from snapshot: UsageSnapshot,
        zoneID: CKRecordZone.ID
    ) throws -> CKRecord {
        let id = recordID(for: snapshot.providerId, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: id)

        record["providerId"] = snapshot.providerId as CKRecordValue
        record["capturedAt"] = snapshot.capturedAt as CKRecordValue
        record["accountEmail"] = snapshot.accountEmail as CKRecordValue?
        record["accountOrganization"] = snapshot.accountOrganization as CKRecordValue?

        if let tier = snapshot.accountTier {
            record["accountTier"] = CodableAccountTier(from: tier).value as CKRecordValue
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        let codableQuotas = snapshot.quotas.map { CodableQuota(from: $0) }
        record["quotasJSON"] = try encoder.encode(codableQuotas) as CKRecordValue

        if let cost = snapshot.costUsage {
            record["costUsageJSON"] = try encoder.encode(CodableCostUsage(from: cost)) as CKRecordValue
        }

        return record
    }

    // MARK: - CKRecord → Domain

    /// Converts a CKRecord back into a UsageSnapshot domain object.
    static func snapshot(from record: CKRecord) throws -> UsageSnapshot {
        guard let providerId = record["providerId"] as? String,
              let capturedAt = record["capturedAt"] as? Date,
              let quotasData = record["quotasJSON"] as? Data else {
            throw CloudSyncError.invalidRecord
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let codableQuotas = try decoder.decode([CodableQuota].self, from: quotasData)
        let quotas = codableQuotas.map { $0.toDomain() }

        let accountTier: AccountTier? = (record["accountTier"] as? String)
            .map { CodableAccountTier(value: $0).toDomain() }

        let costUsage: CostUsage? = try (record["costUsageJSON"] as? Data)
            .map { try decoder.decode(CodableCostUsage.self, from: $0).toDomain() }

        return UsageSnapshot(
            providerId: providerId,
            quotas: quotas,
            capturedAt: capturedAt,
            accountEmail: record["accountEmail"] as? String,
            accountOrganization: record["accountOrganization"] as? String,
            accountTier: accountTier,
            costUsage: costUsage
        )
    }
}
