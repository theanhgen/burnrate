import Foundation
import Testing
@testable import Domain

@Suite
struct CostProjectionInsightGeneratorTests {
    private let generator = CostProjectionInsightGenerator()

    private func makeReport(todayCost: Decimal, yesterdayCost: Decimal) -> DailyUsageReport {
        DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: todayCost,
                totalTokens: 1_000_000,
                workingTime: 3600,
                sessionCount: 3
            ),
            previous: DailyUsageStat(
                date: Date().addingTimeInterval(-86400),
                totalCost: yesterdayCost,
                totalTokens: 800_000,
                workingTime: 3000,
                sessionCount: 2
            )
        )
    }

    // MARK: - No Data

    @Test func `returns empty when no daily report`() {
        let context = InsightContext(providerId: "claude")
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when zero cost today`() {
        let report = makeReport(todayCost: 0, yesterdayCost: 10)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - High Projection (>$500/mo)

    @Test func `generates caution for high projection`() {
        // avg = (25 + 15) / 2 = 20/day → 600/month
        let report = makeReport(todayCost: 25, yesterdayCost: 15)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].title.contains("$600"))
    }

    // MARK: - Moderate Projection ($100-500)

    @Test func `generates neutral for moderate projection`() {
        // avg = (8 + 6) / 2 = 7/day → 210/month
        let report = makeReport(todayCost: 8, yesterdayCost: 6)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("$210"))
    }

    // MARK: - Light Projection (<$100)

    @Test func `generates positive for light projection`() {
        // avg = (2 + 1) / 2 = 1.5/day → 45/month
        let report = makeReport(todayCost: 2, yesterdayCost: 1)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("Light"))
    }

    // MARK: - Today Only (no yesterday)

    @Test func `uses today only when yesterday is zero`() {
        // today = 20/day → 600/month (high)
        let report = makeReport(todayCost: 20, yesterdayCost: 0)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].title.contains("$600"))
    }

    // MARK: - Provider ID

    @Test func `includes provider id in insight`() {
        let report = makeReport(todayCost: 5, yesterdayCost: 3)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights[0].providerId == "claude")
    }

    @Test func `works without provider id`() {
        let report = makeReport(todayCost: 5, yesterdayCost: 3)
        let context = InsightContext(dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].providerId == nil)
    }
}
