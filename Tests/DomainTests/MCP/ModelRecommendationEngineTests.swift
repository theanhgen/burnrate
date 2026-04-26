import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite
struct ModelRecommendationEngineTests {

    private func makeProvider(
        id: String,
        name: String,
        snapshot: UsageSnapshot?,
        enabled: Bool = true
    ) -> any AIProvider {
        let settings = MockProviderSettingsRepository()
        given(settings).isEnabled(forProvider: .any, defaultValue: .any).willReturn(enabled)
        given(settings).isEnabled(forProvider: .any).willReturn(enabled)
        given(settings).setEnabled(.any, forProvider: .any).willReturn()
        given(settings).customCardURL(forProvider: .any).willReturn(nil)
        given(settings).setCustomCardURL(.any, forProvider: .any).willReturn()

        let probe = MockUsageProbe()
        given(probe).isAvailable().willReturn(true)
        if let snapshot {
            given(probe).probe().willReturn(snapshot)
        }

        let provider = ClaudeProvider(probe: probe, settingsRepository: settings)
        // We need to set the snapshot by refreshing if one was given
        return provider
    }

    /// Helper to create a snapshot-bearing provider via direct refresh
    private func makeProviderWithSnapshot(
        id: String,
        name: String,
        quotas: [UsageQuota],
        tier: AccountTier? = nil
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
            accountTier: tier
        )
        let probe = MockUsageProbe()
        given(probe).isAvailable().willReturn(true)
        given(probe).probe().willReturn(snapshot)

        let provider = ClaudeProvider(probe: probe, settingsRepository: settings)
        try? await provider.refresh()
        return provider
    }

    // MARK: - Basic Recommendation Tests

    @Test
    func `recommends when no providers enabled`() {
        let result = ModelRecommendationEngine.recommend(
            complexity: .medium,
            providers: []
        )
        #expect(result.recommendation == "No providers enabled")
        #expect(!result.warnings.isEmpty)
    }

    @Test
    func `recommends healthy provider for high complexity`() async {
        let provider = await makeProviderWithSnapshot(
            id: "claude",
            name: "Claude",
            quotas: [
                UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
                UsageQuota(percentRemaining: 60, quotaType: .weekly, providerId: "claude"),
            ],
            tier: .claudeMax
        )

        let result = ModelRecommendationEngine.recommend(
            complexity: .high,
            providers: [provider]
        )

        #expect(result.recommendation.contains("Claude"))
        #expect(result.warnings.isEmpty)
    }

    @Test
    func `warns about low quota provider`() async {
        let provider = await makeProviderWithSnapshot(
            id: "claude",
            name: "Claude",
            quotas: [
                UsageQuota(percentRemaining: 30, quotaType: .session, providerId: "claude"),
            ]
        )

        let result = ModelRecommendationEngine.recommend(
            complexity: .medium,
            providers: [provider]
        )

        #expect(result.recommendation.contains("Claude"))
        #expect(result.warnings.contains { $0.contains("getting low") })
    }

    @Test
    func `excludes depleted providers`() async {
        let depleted = await makeProviderWithSnapshot(
            id: "claude",
            name: "Claude",
            quotas: [
                UsageQuota(percentRemaining: 0, quotaType: .session, providerId: "claude"),
            ]
        )

        let result = ModelRecommendationEngine.recommend(
            complexity: .medium,
            providers: [depleted]
        )

        #expect(result.recommendation.contains("depleted"))
        #expect(result.warnings.contains { $0.contains("depleted") })
    }

    @Test
    func `prefers healthier provider when multiple available`() async {
        let healthy = await makeProviderWithSnapshot(
            id: "claude",
            name: "Claude",
            quotas: [
                UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
            ]
        )

        let warning = await makeProviderWithSnapshot(
            id: "claude",
            name: "Codex",
            quotas: [
                UsageQuota(percentRemaining: 30, quotaType: .session, providerId: "codex"),
            ]
        )

        let result = ModelRecommendationEngine.recommend(
            complexity: .medium,
            providers: [warning, healthy]
        )

        // Should recommend the healthy one
        #expect(result.recommendation.contains("Claude"))
        #expect(!result.alternatives.isEmpty)
    }
}
