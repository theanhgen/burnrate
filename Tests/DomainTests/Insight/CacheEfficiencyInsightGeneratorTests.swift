import Foundation
import Testing
@testable import Domain

@Suite
struct CacheEfficiencyInsightGeneratorTests {
    private let generator = CacheEfficiencyInsightGenerator()

    private func makeReport(cache: CacheStats?) -> DailyUsageReport {
        DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: 20,
                totalTokens: 5_000_000,
                workingTime: 7200,
                sessionCount: 3,
                cacheStats: cache
            ),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
    }

    // MARK: - No Data

    @Test func `returns empty when no daily report`() {
        let context = InsightContext(providerId: "claude")
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when no cache stats`() {
        let report = makeReport(cache: nil)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Significant Savings (>$5)

    @Test func `generates positive insight for significant cache savings`() {
        let cache = CacheStats(
            cacheReadTokens: 3_000_000,
            cacheCreationTokens: 500_000,
            estimatedSavings: 12
        )
        let context = InsightContext(providerId: "claude", dailyReport: makeReport(cache: cache))
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("$12"))
    }

    // MARK: - High Cache Hit Rate (>50%)

    @Test func `generates positive insight for high cache hit rate`() {
        let cache = CacheStats(
            cacheReadTokens: 800_000,
            cacheCreationTokens: 200_000,
            estimatedSavings: 3 // below $5 threshold
        )
        let context = InsightContext(providerId: "claude", dailyReport: makeReport(cache: cache))
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("80%"))
    }

    // MARK: - Low Cache Usage (<10%)

    @Test func `generates neutral insight for minimal caching`() {
        let cache = CacheStats(
            cacheReadTokens: 5_000,
            cacheCreationTokens: 100_000,
            estimatedSavings: Decimal(string: "0.01")!
        )
        let context = InsightContext(providerId: "claude", dailyReport: makeReport(cache: cache))
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("Minimal"))
    }

    // MARK: - Middle Range (no insight)

    @Test func `returns empty for moderate cache usage`() {
        // 30% read ratio, $2 savings — doesn't match any threshold
        let cache = CacheStats(
            cacheReadTokens: 300_000,
            cacheCreationTokens: 700_000,
            estimatedSavings: 2
        )
        let context = InsightContext(providerId: "claude", dailyReport: makeReport(cache: cache))
        let insights = generator.generate(context: context)
        #expect(insights.isEmpty)
    }
}
