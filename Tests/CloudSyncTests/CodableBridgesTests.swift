import Testing
import Foundation
@testable import Domain
@testable import CloudSync

@Suite("CodableBridges")
struct CodableBridgesTests {

    // MARK: - CodableQuota

    @Test("Round-trips a session quota")
    func sessionQuotaRoundTrip() throws {
        let original = UsageQuota(
            percentRemaining: 72.5,
            quotaType: .session,
            providerId: "claude",
            resetsAt: Date(timeIntervalSince1970: 1_700_000_000),
            resetText: "Resets in 3h"
        )

        let codable = CodableQuota(from: original)
        let restored = codable.toDomain()

        #expect(restored.percentRemaining == original.percentRemaining)
        #expect(restored.quotaType == .session)
        #expect(restored.providerId == "claude")
        #expect(restored.resetsAt == original.resetsAt)
        #expect(restored.resetText == "Resets in 3h")
        #expect(restored.dollarRemaining == nil)
    }

    @Test("Round-trips a weekly quota")
    func weeklyQuotaRoundTrip() throws {
        let original = UsageQuota(
            percentRemaining: 45.0,
            quotaType: .weekly,
            providerId: "codex"
        )

        let restored = CodableQuota(from: original).toDomain()

        #expect(restored.quotaType == .weekly)
        #expect(restored.providerId == "codex")
    }

    @Test("Round-trips a model-specific quota")
    func modelSpecificQuotaRoundTrip() throws {
        let original = UsageQuota(
            percentRemaining: 30.0,
            quotaType: .modelSpecific("opus"),
            providerId: "claude"
        )

        let restored = CodableQuota(from: original).toDomain()

        #expect(restored.quotaType == .modelSpecific("opus"))
    }

    @Test("Round-trips a time-limit quota")
    func timeLimitQuotaRoundTrip() throws {
        let original = UsageQuota(
            percentRemaining: 88.0,
            quotaType: .timeLimit("MCP Usage"),
            providerId: "claude"
        )

        let restored = CodableQuota(from: original).toDomain()

        #expect(restored.quotaType == .timeLimit("MCP Usage"))
    }

    @Test("Round-trips a dollar-based quota")
    func dollarQuotaRoundTrip() throws {
        let original = UsageQuota(
            percentRemaining: 100,
            quotaType: .session,
            providerId: "claude",
            dollarRemaining: Decimal(string: "49.95")
        )

        let restored = CodableQuota(from: original).toDomain()

        #expect(restored.dollarRemaining == Decimal(string: "49.95"))
    }

    @Test("JSON round-trip preserves array of quotas")
    func jsonArrayRoundTrip() throws {
        let quotas = [
            CodableQuota(from: UsageQuota(percentRemaining: 72, quotaType: .session, providerId: "claude")),
            CodableQuota(from: UsageQuota(percentRemaining: 50, quotaType: .weekly, providerId: "claude")),
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(quotas)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode([CodableQuota].self, from: data)

        #expect(restored.count == 2)
        #expect(restored[0].toDomain().quotaType == .session)
        #expect(restored[1].toDomain().quotaType == .weekly)
    }

    // MARK: - CodableCostUsage

    @Test("Round-trips cost usage")
    func costUsageRoundTrip() throws {
        let original = CostUsage(
            totalCost: Decimal(string: "12.34")!,
            budget: Decimal(string: "20.00")!,
            apiDuration: 379.7,
            wallDuration: 23590.2,
            linesAdded: 150,
            linesRemoved: 42,
            providerId: "claude",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            resetsAt: Date(timeIntervalSince1970: 1_700_100_000),
            resetText: "Resets Jan 1"
        )

        let codable = CodableCostUsage(from: original)
        let restored = codable.toDomain()

        #expect(restored.totalCost == Decimal(string: "12.34"))
        #expect(restored.budget == Decimal(string: "20.00"))
        #expect(restored.apiDuration == 379.7)
        #expect(restored.wallDuration == 23590.2)
        #expect(restored.linesAdded == 150)
        #expect(restored.linesRemoved == 42)
        #expect(restored.providerId == "claude")
        #expect(restored.resetText == "Resets Jan 1")
    }

    @Test("Cost usage JSON round-trip preserves Decimal precision")
    func costUsageJsonPrecision() throws {
        let original = CostUsage(
            totalCost: Decimal(string: "0.01")!,
            apiDuration: 1.0,
            providerId: "claude"
        )

        let codable = CodableCostUsage(from: original)
        let encoder = JSONEncoder()
        let data = try encoder.encode(codable)
        let restored = try JSONDecoder().decode(CodableCostUsage.self, from: data).toDomain()

        #expect(restored.totalCost == Decimal(string: "0.01"))
    }

    // MARK: - CodableAccountTier

    @Test("Round-trips all account tiers")
    func accountTierRoundTrip() throws {
        let tiers: [AccountTier] = [.claudeMax, .claudePro, .claudeApi, .custom("ULTRA")]

        for tier in tiers {
            let restored = CodableAccountTier(from: tier).toDomain()
            #expect(restored == tier)
        }
    }
}
