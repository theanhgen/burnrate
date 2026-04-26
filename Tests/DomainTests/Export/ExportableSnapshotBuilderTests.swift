import Testing
import Foundation
@testable import Domain

@Suite
struct ExportableSnapshotBuilderTests {

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let resetDate = Date(timeIntervalSince1970: 1_700_018_000)

    @Test
    func `builds exportable snapshot from provider inputs`() {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [
                UsageQuota(
                    percentRemaining: 42.5,
                    quotaType: .session,
                    providerId: "claude",
                    resetsAt: Self.resetDate
                ),
                UsageQuota(
                    percentRemaining: 68.0,
                    quotaType: .weekly,
                    providerId: "claude"
                ),
            ],
            capturedAt: Self.now,
            accountEmail: "test@example.com",
            accountTier: .claudeMax
        )

        let input = ProviderExportInput(id: "claude", name: "Claude", snapshot: snapshot)
        let result = ExportableSnapshotBuilder.build(
            providers: [input],
            appVersion: "1.0.0",
            exportedAt: Self.now
        )

        #expect(result.appVersion == "1.0.0")
        #expect(result.providers.count == 1)

        let p = result.providers[0]
        #expect(p.id == "claude")
        #expect(p.name == "Claude")
        #expect(p.status == "warning") // 42.5% remaining = warning
        #expect(p.accountEmail == "test@example.com")
        #expect(p.accountTier == "Claude Max")
        #expect(p.quotas.count == 2)

        let session = p.quotas[0]
        #expect(session.type == "Session")
        #expect(session.percentRemaining == 42.5)
        #expect(session.percentUsed == 57.5)
        #expect(session.status == "warning")
        #expect(session.resetsAt == Self.resetDate)
    }

    @Test
    func `handles provider with no snapshot`() {
        let input = ProviderExportInput(id: "codex", name: "Codex", snapshot: nil)
        let result = ExportableSnapshotBuilder.build(
            providers: [input],
            appVersion: "1.0.0",
            exportedAt: Self.now
        )

        let p = result.providers[0]
        #expect(p.status == "unknown")
        #expect(p.quotas.isEmpty)
        #expect(p.costUsage == nil)
    }

    @Test
    func `includes cost usage when present`() {
        let costUsage = CostUsage(
            totalCost: Decimal(string: "12.50")!,
            budget: Decimal(string: "100.00")!,
            apiDuration: 379.7,
            wallDuration: 8100.0,
            linesAdded: 450,
            linesRemoved: 120,
            providerId: "claude"
        )

        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Self.now,
            costUsage: costUsage
        )

        let input = ProviderExportInput(id: "claude", name: "Claude", snapshot: snapshot)
        let result = ExportableSnapshotBuilder.build(providers: [input], appVersion: "1.0.0")

        let c = result.providers[0].costUsage!
        #expect(c.totalCost == "$12.50")
        #expect(c.budget == "$100.00")
        #expect(c.linesAdded == 450)
        #expect(c.linesRemoved == 120)
    }

    @Test
    func `includes daily usage when present`() {
        let report = DailyUsageReport(
            today: DailyUsageStat(
                date: Self.now,
                totalCost: Decimal(string: "5.30")!,
                totalTokens: 2_100_000,
                workingTime: 13500,
                sessionCount: 4
            ),
            previous: DailyUsageStat(
                date: Self.now.addingTimeInterval(-86400),
                totalCost: Decimal(string: "8.20")!,
                totalTokens: 3_500_000,
                workingTime: 17700,
                sessionCount: 6
            )
        )

        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Self.now,
            dailyUsageReport: report
        )

        let input = ProviderExportInput(id: "claude", name: "Claude", snapshot: snapshot)
        let result = ExportableSnapshotBuilder.build(providers: [input], appVersion: "1.0.0")

        let d = result.providers[0].dailyUsage!
        #expect(d.todayCost == "$5.30")
        #expect(d.todayTokens == "2.1M")
        #expect(d.todaySessions == 4)
        #expect(d.previousCost == "$8.20")
    }

    @Test
    func `includes bedrock usage when present`() {
        let model = BedrockModel(
            id: "anthropic.claude-opus-4-5",
            displayName: "Claude Opus 4.5",
            vendor: "Anthropic",
            inputPricePer1M: 15,
            outputPricePer1M: 75
        )
        let bedrockUsage = BedrockUsageSummary(
            modelUsages: [
                BedrockModelUsage(model: model, invocations: 100, inputTokens: 500_000, outputTokens: 200_000),
            ],
            region: "us-east-1",
            periodStart: Self.now.addingTimeInterval(-86400),
            periodEnd: Self.now,
            dailyBudget: 50
        )

        let snapshot = UsageSnapshot(
            providerId: "bedrock",
            quotas: [],
            capturedAt: Self.now,
            bedrockUsage: bedrockUsage
        )

        let input = ProviderExportInput(id: "bedrock", name: "Bedrock", snapshot: snapshot)
        let result = ExportableSnapshotBuilder.build(providers: [input], appVersion: "1.0.0")

        let b = result.providers[0].bedrockUsage!
        #expect(b.region == "us-east-1")
        #expect(b.totalInvocations == 100)
        #expect(b.models.count == 1)
        #expect(b.models[0].name == "Claude Opus 4.5")
    }
}
