import Foundation
import Testing
@testable import Domain

@Suite
struct TokenEfficiencyInsightGeneratorTests {
    private let generator = TokenEfficiencyInsightGenerator()

    private func makeReport(inputTokens: Int, outputTokens: Int) -> DailyUsageReport {
        let breakdown = [
            ModelUsageStat(
                model: "claude-sonnet-4-6",
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                totalTokens: inputTokens + outputTokens,
                cost: 5,
                percentage: 100
            )
        ]
        return DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: 10,
                totalTokens: inputTokens + outputTokens,
                workingTime: 3600,
                sessionCount: 2,
                modelBreakdown: breakdown
            ),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
    }

    // MARK: - No Data

    @Test func `returns empty when no daily report`() {
        let context = InsightContext(providerId: "claude")
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when no model breakdown`() {
        let report = DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: 10,
                totalTokens: 100_000,
                workingTime: 3600,
                sessionCount: 2
            ),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when zero input tokens`() {
        let report = makeReport(inputTokens: 0, outputTokens: 50_000)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Generation Heavy (ratio > 5)

    @Test func `detects generation heavy workload`() {
        // 600k output / 100k input = 6x ratio
        let report = makeReport(inputTokens: 100_000, outputTokens: 600_000)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].title.contains("Generation-heavy"))
        #expect(insights[0].title.contains("6x"))
        #expect(insights[0].severity == .neutral)
    }

    // MARK: - Balanced (ratio 2-5)

    @Test func `detects balanced workload`() {
        // 300k output / 100k input = 3x ratio
        let report = makeReport(inputTokens: 100_000, outputTokens: 300_000)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].title.contains("Balanced"))
        #expect(insights[0].title.contains("3x"))
    }

    // MARK: - Context Heavy (ratio < 2)

    @Test func `detects context heavy workload`() {
        // 100k output / 100k input = 1x ratio
        let report = makeReport(inputTokens: 100_000, outputTokens: 100_000)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].title.contains("Context-heavy"))
    }

    // MARK: - Multi-Model Aggregation

    @Test func `aggregates across multiple models`() {
        let breakdown = [
            ModelUsageStat(model: "claude-opus-4-6", inputTokens: 50_000, outputTokens: 400_000, totalTokens: 450_000, cost: 8, percentage: 60),
            ModelUsageStat(model: "claude-sonnet-4-6", inputTokens: 50_000, outputTokens: 200_000, totalTokens: 250_000, cost: 2, percentage: 40),
        ]
        let report = DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: 10,
                totalTokens: 700_000,
                workingTime: 3600,
                sessionCount: 2,
                modelBreakdown: breakdown
            ),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
        // total input = 100k, total output = 600k → 6x ratio
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].title.contains("Generation-heavy"))
    }

    // MARK: - Provider ID

    @Test func `includes provider id`() {
        let report = makeReport(inputTokens: 100_000, outputTokens: 100_000)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights[0].providerId == "claude")
    }

    @Test func `works without provider id`() {
        let report = makeReport(inputTokens: 100_000, outputTokens: 100_000)
        let context = InsightContext(dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].providerId == nil)
    }
}
