import Foundation
import Testing
@testable import Domain

@Suite
struct DepletionInsightGeneratorTests {
    private let generator = DepletionInsightGenerator()

    private func makeContext(
        forecast: QuotaForecast?,
        quotas: [UsageQuota] = [],
        now: Date = Date()
    ) -> InsightContext {
        InsightContext(
            providerId: "claude",
            liveQuotas: quotas,
            forecast: forecast,
            now: now
        )
    }

    // MARK: - No Forecast

    @Test func `returns empty when no forecast available`() {
        let insights = generator.generate(context: makeContext(forecast: nil))
        #expect(insights.isEmpty)
    }

    // MARK: - Already Depleted

    @Test func `generates critical insight when already depleted`() {
        let now = Date()
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-3600), percentUsed: 95),
                (timestamp: now, percentUsed: 105),
            ],
            now: now
        )!

        let insights = generator.generate(context: makeContext(forecast: forecast, now: now))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .critical)
        #expect(insights[0].severity == .urgent)
        #expect(insights[0].category == .depletion)
        #expect(insights[0].title == "Quota depleted")
    }

    // MARK: - Depleting Within 1 Hour

    @Test func `generates critical insight when depleting within one hour`() {
        let now = Date()
        // 80% used, 20%/hr -> 1 hour to depletion, but we want <1h
        // Let's use 90% used, 20%/hr -> 30min to depletion
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-1800), percentUsed: 80),
                (timestamp: now, percentUsed: 90),
            ],
            now: now
        )!

        let insights = generator.generate(context: makeContext(forecast: forecast, now: now))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .critical)
        #expect(insights[0].severity == .urgent)
        #expect(insights[0].title.contains("m"))
    }

    // MARK: - Depleting Within 8 Hours

    @Test func `generates high insight when depleting within eight hours`() {
        let now = Date()
        // 50% used, 10%/hr -> 5 hours to depletion
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-3600), percentUsed: 40),
                (timestamp: now, percentUsed: 50),
            ],
            now: now
        )!

        let insights = generator.generate(context: makeContext(forecast: forecast, now: now))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .high)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].title.contains("5h"))
    }

    // MARK: - Distant Depletion

    @Test func `generates low insight when depletion is far away`() {
        let now = Date()
        // 10% used, 2%/hr -> 45 hours to depletion
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-3600), percentUsed: 8),
                (timestamp: now, percentUsed: 10),
            ],
            now: now
        )!

        let insights = generator.generate(context: makeContext(forecast: forecast, now: now))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .low)
        #expect(insights[0].severity == .neutral)
    }

    // MARK: - No Depletion Expected

    @Test func `generates positive insight when no depletion expected`() {
        let now = Date()
        // Usage going down — no depletion
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-3600), percentUsed: 50),
                (timestamp: now, percentUsed: 40),
            ],
            now: now
        )!

        // Forecast with no depletion and zero burn rate produces no insight
        let insights = generator.generate(context: makeContext(forecast: forecast, now: now))
        #expect(insights.isEmpty)
    }

    // MARK: - Provider ID

    @Test func `includes provider id in insight`() {
        let now = Date()
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-3600), percentUsed: 40),
                (timestamp: now, percentUsed: 50),
            ],
            now: now
        )!

        let insights = generator.generate(context: makeContext(forecast: forecast, now: now))
        #expect(insights[0].providerId == "claude")
        #expect(insights[0].id.contains("claude"))
    }
}
