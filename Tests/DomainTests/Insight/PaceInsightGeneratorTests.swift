import Foundation
import Testing
@testable import Domain

@Suite
struct PaceInsightGeneratorTests {
    private let generator = PaceInsightGenerator()

    private func makeQuota(
        percentRemaining: Double,
        resetsAt: Date? = Date().addingTimeInterval(3600 * 3) // 3h from now in a 5h window
    ) -> UsageQuota {
        UsageQuota(
            percentRemaining: percentRemaining,
            quotaType: .session,
            providerId: "claude",
            resetsAt: resetsAt
        )
    }

    private func makeContext(quotas: [UsageQuota]) -> InsightContext {
        InsightContext(providerId: "claude", liveQuotas: quotas)
    }

    // MARK: - No Data

    @Test func `returns empty when no quotas`() {
        let insights = generator.generate(context: makeContext(quotas: []))
        #expect(insights.isEmpty)
    }

    @Test func `returns empty when pace is unknown`() {
        // No resetsAt -> pace is unknown
        let quota = UsageQuota(
            percentRemaining: 50,
            quotaType: .session,
            providerId: "claude",
            resetsAt: nil
        )
        let insights = generator.generate(context: makeContext(quotas: [quota]))
        #expect(insights.isEmpty)
    }

    // MARK: - Running Hot (>20% ahead)

    @Test func `generates high caution when running hot`() {
        // 5h window, 3h remaining = 2h elapsed = 40% time elapsed
        // 75% used vs 40% expected = 35% ahead
        let quota = makeQuota(percentRemaining: 25)
        let insights = generator.generate(context: makeContext(quotas: [quota]))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .high)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].category == .pace)
        #expect(insights[0].title == "Running hot")
    }

    // MARK: - Slightly Ahead (5-20%)

    @Test func `generates medium caution when slightly ahead`() {
        // 5h window, 3h remaining = 2h elapsed = 40% time elapsed
        // 50% used vs 40% expected = 10% ahead
        let quota = makeQuota(percentRemaining: 50)
        let insights = generator.generate(context: makeContext(quotas: [quota]))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].title == "Slightly ahead of pace")
    }

    // MARK: - On Pace

    @Test func `generates low positive when on pace`() {
        // 5h window, 3h remaining = 2h elapsed = 40% time elapsed
        // 42% used vs 40% expected = 2% ahead (within 5% threshold)
        let quota = makeQuota(percentRemaining: 58)
        let insights = generator.generate(context: makeContext(quotas: [quota]))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .low)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title == "Right on track")
    }

    // MARK: - Behind

    @Test func `generates low positive when behind pace`() {
        // 5h window, 3h remaining = 2h elapsed = 40% time elapsed
        // 10% used vs 40% expected = 30% behind
        let quota = makeQuota(percentRemaining: 90)
        let insights = generator.generate(context: makeContext(quotas: [quota]))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .low)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title == "Room to spare")
    }

    // MARK: - Prefers Session Quota

    @Test func `prefers session quota over weekly`() {
        let session = makeQuota(percentRemaining: 25) // running hot
        let weekly = UsageQuota(
            percentRemaining: 90,
            quotaType: .weekly,
            providerId: "claude",
            resetsAt: Date().addingTimeInterval(86400 * 5)
        )

        let insights = generator.generate(context: makeContext(quotas: [weekly, session]))
        #expect(insights.count == 1)
        #expect(insights[0].title == "Running hot")
    }
}
