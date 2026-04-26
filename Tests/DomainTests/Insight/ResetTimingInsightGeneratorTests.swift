import Foundation
import Testing
@testable import Domain

@Suite
struct ResetTimingInsightGeneratorTests {
    private let generator = ResetTimingInsightGenerator()

    private func makeQuota(
        percentRemaining: Double,
        minutesUntilReset: Int,
        quotaType: QuotaType = .session,
        providerId: String = "claude"
    ) -> UsageQuota {
        UsageQuota(
            percentRemaining: percentRemaining,
            quotaType: quotaType,
            providerId: providerId,
            resetsAt: Date().addingTimeInterval(Double(minutesUntilReset * 60))
        )
    }

    // MARK: - No Data

    @Test func `returns empty when no quotas`() {
        let context = InsightContext(providerId: "claude")
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when no reset time`() {
        let quota = UsageQuota(
            percentRemaining: 50,
            quotaType: .session,
            providerId: "claude"
        )
        let context = InsightContext(providerId: "claude", liveQuotas: [quota])
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Reset <1h, Depleted → "Hang tight"

    @Test func `advises patience when depleted and resetting soon`() {
        let quota = makeQuota(percentRemaining: 0, minutesUntilReset: 25)
        let context = InsightContext(providerId: "claude", liveQuotas: [quota])
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("Refreshes"))
        #expect(insights[0].id.contains("depleted"))
    }

    // MARK: - Reset <1h, >20% Remaining → "Push hard"

    @Test func `encourages usage when plenty left and resetting soon`() {
        let quota = makeQuota(percentRemaining: 35, minutesUntilReset: 45)
        let context = InsightContext(providerId: "claude", liveQuotas: [quota])
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].priority == .high)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("Use it"))
        #expect(insights[0].title.contains("35%"))
    }

    // MARK: - Reset <2h, >40% Remaining → "Plenty left"

    @Test func `suggests using quota when reset in under 2h with plenty left`() {
        let quota = makeQuota(percentRemaining: 55, minutesUntilReset: 90)
        let context = InsightContext(providerId: "claude", liveQuotas: [quota])
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("55%"))
        #expect(insights[0].detail.contains("use it or lose it"))
    }

    // MARK: - Reset Far Away → No Insight

    @Test func `returns empty when reset is far away`() {
        let quota = makeQuota(percentRemaining: 80, minutesUntilReset: 180)
        let context = InsightContext(providerId: "claude", liveQuotas: [quota])
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Edge Cases

    @Test func `prefers session quota over weekly`() {
        let session = makeQuota(percentRemaining: 0, minutesUntilReset: 20, quotaType: .session)
        let weekly = makeQuota(percentRemaining: 80, minutesUntilReset: 30, quotaType: .weekly)
        let context = InsightContext(providerId: "claude", liveQuotas: [session, weekly])
        let insights = generator.generate(context: context)

        // Should use session (depleted) not weekly (plenty left)
        #expect(insights.count == 1)
        #expect(insights[0].id.contains("depleted"))
    }

    @Test func `falls back to first quota when no session type`() {
        let weekly = makeQuota(percentRemaining: 50, minutesUntilReset: 30, quotaType: .weekly)
        let context = InsightContext(providerId: "claude", liveQuotas: [weekly])
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].title.contains("Use it"))
    }

    @Test func `low remaining with imminent reset gets depleted path`() {
        // 5% remaining, 15 min to reset — not > 20%, so no "push hard"
        // Also not depleted (5% > 0), so no "hang tight"
        // Falls through to <2h check: 15min < 2h, but 5% < 40%, so no insight
        let quota = makeQuota(percentRemaining: 5, minutesUntilReset: 15)
        let context = InsightContext(providerId: "claude", liveQuotas: [quota])
        #expect(generator.generate(context: context).isEmpty)
    }
}
