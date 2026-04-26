import Foundation
import Testing
@testable import Domain

@Suite
struct CrossProviderInsightGeneratorTests {
    private let generator = CrossProviderInsightGenerator()

    private func makeQuota(
        providerId: String,
        percentUsed: Double,
        quotaType: QuotaType = .session
    ) -> UsageQuota {
        UsageQuota(
            percentRemaining: 100 - percentUsed,
            quotaType: quotaType,
            providerId: providerId
        )
    }

    // MARK: - No Data / Single Provider

    @Test func `returns empty when provider id is set`() {
        let quotas = [makeQuota(providerId: "claude", percentUsed: 80)]
        let context = InsightContext(providerId: "claude", liveQuotas: quotas)
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when no quotas`() {
        let context = InsightContext()
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty with only one provider`() {
        let quotas = [makeQuota(providerId: "claude", percentUsed: 80)]
        let context = InsightContext(liveQuotas: quotas)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Dominant Provider (>70%)

    @Test func `identifies dominant provider`() {
        let quotas = [
            makeQuota(providerId: "claude", percentUsed: 80),
            makeQuota(providerId: "codex", percentUsed: 20),
        ]
        let context = InsightContext(liveQuotas: quotas)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].title.lowercased().contains("claude"))
        #expect(insights[0].id == "cross-provider-dominant")
    }

    // MARK: - Balanced Usage

    @Test func `reports balanced when no provider dominates`() {
        let quotas = [
            makeQuota(providerId: "claude", percentUsed: 40),
            makeQuota(providerId: "codex", percentUsed: 35),
            makeQuota(providerId: "gemini", percentUsed: 30),
        ]
        let context = InsightContext(liveQuotas: quotas)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].id == "cross-provider-balanced")
        #expect(insights[0].title.contains("3"))
    }

    // MARK: - Quota Type Fallback

    @Test func `falls back to weekly when no session quotas`() {
        let quotas = [
            makeQuota(providerId: "claude", percentUsed: 90, quotaType: .weekly),
            makeQuota(providerId: "codex", percentUsed: 10, quotaType: .weekly),
        ]
        let context = InsightContext(liveQuotas: quotas)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].id == "cross-provider-dominant")
    }

    // MARK: - Zero Usage

    @Test func `returns empty when all usage is zero`() {
        let quotas = [
            makeQuota(providerId: "claude", percentUsed: 0),
            makeQuota(providerId: "codex", percentUsed: 0),
        ]
        let context = InsightContext(liveQuotas: quotas)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Provider ID

    @Test func `has no provider id in insight`() {
        let quotas = [
            makeQuota(providerId: "claude", percentUsed: 80),
            makeQuota(providerId: "codex", percentUsed: 20),
        ]
        let context = InsightContext(liveQuotas: quotas)
        let insights = generator.generate(context: context)

        // Cross-provider insight shouldn't be scoped to a single provider
        #expect(insights[0].providerId == nil)
    }
}
