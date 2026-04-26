import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite
struct MCPResponseBuilderTests {

    private func makeProviderWithSnapshot(
        id: String,
        quotas: [UsageQuota],
        tier: AccountTier? = nil,
        costUsage: CostUsage? = nil
    ) async -> any AIProvider {
        let settings = MockProviderSettingsRepository()
        given(settings).isEnabled(forProvider: .any, defaultValue: .any).willReturn(true)
        given(settings).isEnabled(forProvider: .any).willReturn(true)
        given(settings).setEnabled(.any, forProvider: .any).willReturn()
        given(settings).customCardURL(forProvider: .any).willReturn(nil)
        given(settings).setCustomCardURL(.any, forProvider: .any).willReturn()

        let snapshot = UsageSnapshot(
            providerId: id,
            quotas: quotas,
            capturedAt: Date(),
            accountTier: tier,
            costUsage: costUsage
        )
        let probe = MockUsageProbe()
        given(probe).isAvailable().willReturn(true)
        given(probe).probe().willReturn(snapshot)

        let provider = ClaudeProvider(probe: probe, settingsRepository: settings)
        try? await provider.refresh()
        return provider
    }

    // MARK: - Status Response

    @Test
    func `builds status response with correct structure`() async {
        let provider = await makeProviderWithSnapshot(
            id: "claude",
            quotas: [
                UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude"),
                UsageQuota(percentRemaining: 35, quotaType: .weekly, providerId: "claude"),
            ],
            tier: .claudeMax
        )

        let response = MCPResponseBuilder.buildStatusResponse(
            providers: [provider],
            overallStatus: .warning
        )

        #expect(response.overallStatus == "warning")
        #expect(response.providers.count == 1)
        #expect(!response.capturedAt.isEmpty)

        let summary = response.providers[0]
        #expect(summary.id == "claude")
        #expect(summary.accountTier == "MAX")
        #expect(summary.quotas.count == 2)

        let sessionQuota = summary.quotas.first { $0.type == "Session" }
        #expect(sessionQuota?.percentRemaining == 65)
        #expect(sessionQuota?.status == "healthy")

        let weeklyQuota = summary.quotas.first { $0.type == "Weekly" }
        #expect(weeklyQuota?.percentRemaining == 35)
        #expect(weeklyQuota?.status == "warning")
    }

    @Test
    func `builds status response with model-specific quotas`() async {
        let provider = await makeProviderWithSnapshot(
            id: "claude",
            quotas: [
                UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude"),
                UsageQuota(percentRemaining: 15, quotaType: .modelSpecific("opus"), providerId: "claude"),
                UsageQuota(percentRemaining: 80, quotaType: .modelSpecific("sonnet"), providerId: "claude"),
            ]
        )

        let response = MCPResponseBuilder.buildStatusResponse(
            providers: [provider],
            overallStatus: .critical
        )

        let summary = response.providers[0]
        // Session quota should be in quotas, model quotas separate
        #expect(summary.quotas.count == 1)
        #expect(summary.modelQuotas.count == 2)
        #expect(summary.modelQuotas.first { $0.model == "opus" }?.status == "critical")
        #expect(summary.modelQuotas.first { $0.model == "sonnet" }?.status == "healthy")
    }

    // MARK: - Detail Response

    @Test
    func `builds detail response with cost usage`() async {
        let cost = CostUsage(
            totalCost: 4.50,
            budget: 20.00,
            apiDuration: 379.7,
            providerId: "claude"
        )

        let provider = await makeProviderWithSnapshot(
            id: "claude",
            quotas: [
                UsageQuota(percentRemaining: 70, quotaType: .session, providerId: "claude"),
            ],
            tier: .claudePro,
            costUsage: cost
        )

        let detail = MCPResponseBuilder.buildDetailResponse(provider: provider)

        #expect(detail != nil)
        #expect(detail?.costUsage?.totalCost == "$4.50")
        #expect(detail?.costUsage?.budget == "$20.00")
        #expect(detail?.accountTier == "PRO")
    }

    @Test
    func `detail response returns nil for provider without snapshot`() {
        let settings = MockProviderSettingsRepository()
        given(settings).isEnabled(forProvider: .any, defaultValue: .any).willReturn(true)
        given(settings).isEnabled(forProvider: .any).willReturn(true)
        given(settings).setEnabled(.any, forProvider: .any).willReturn()
        given(settings).customCardURL(forProvider: .any).willReturn(nil)
        given(settings).setCustomCardURL(.any, forProvider: .any).willReturn()

        let probe = MockUsageProbe()
        let provider = ClaudeProvider(probe: probe, settingsRepository: settings)

        let detail = MCPResponseBuilder.buildDetailResponse(provider: provider)
        #expect(detail == nil)
    }

    // MARK: - JSON Serialization

    @Test
    func `response types are JSON-encodable`() async throws {
        let provider = await makeProviderWithSnapshot(
            id: "claude",
            quotas: [
                UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude"),
            ]
        )

        let response = MCPResponseBuilder.buildStatusResponse(
            providers: [provider],
            overallStatus: .warning
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json!.contains("\"overallStatus\""))
        #expect(json!.contains("\"providers\""))
    }
}
