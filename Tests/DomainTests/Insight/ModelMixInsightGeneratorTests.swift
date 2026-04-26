import Foundation
import Testing
@testable import Domain

@Suite
struct ModelMixInsightGeneratorTests {
    private let generator = ModelMixInsightGenerator()

    private func makeReport(models: [ModelUsageStat]) -> DailyUsageReport {
        let totalCost = models.reduce(Decimal.zero) { $0 + $1.cost }
        let totalTokens = models.reduce(0) { $0 + $1.totalTokens }
        return DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: totalCost,
                totalTokens: totalTokens,
                workingTime: 3600,
                sessionCount: 3,
                modelBreakdown: models
            ),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
    }

    private func makeModel(_ name: String, tokens: Int, pct: Double, cost: Decimal = 10) -> ModelUsageStat {
        ModelUsageStat(
            model: name,
            inputTokens: tokens / 4,
            outputTokens: tokens * 3 / 4,
            totalTokens: tokens,
            cost: cost,
            percentage: pct
        )
    }

    // MARK: - No Data

    @Test func `returns empty when no daily report`() {
        let context = InsightContext(providerId: "claude")
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when model breakdown is empty`() {
        let report = DailyUsageReport(
            today: DailyUsageStat(date: Date(), totalCost: 10, totalTokens: 1000, workingTime: 3600, sessionCount: 1),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Single Model

    @Test func `generates neutral insight for single model`() {
        let report = makeReport(models: [
            makeModel("claude-opus-4-6", tokens: 5_000_000, pct: 100, cost: 38),
        ])
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("Opus"))
    }

    // MARK: - Dominant Model (>60%)

    @Test func `generates insight when top model dominates`() {
        let report = makeReport(models: [
            makeModel("claude-opus-4-6", tokens: 7_000_000, pct: 70, cost: 38),
            makeModel("claude-sonnet-4-6", tokens: 2_000_000, pct: 20, cost: 8),
            makeModel("claude-haiku-4-5-20251001", tokens: 1_000_000, pct: 10, cost: 2),
        ])
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].title.contains("70%"))
    }

    // MARK: - Diverse Model Mix (3+)

    @Test func `generates positive insight for diverse model usage`() {
        let report = makeReport(models: [
            makeModel("claude-opus-4-6", tokens: 4_000_000, pct: 40),
            makeModel("claude-sonnet-4-6", tokens: 3_000_000, pct: 30),
            makeModel("claude-haiku-4-5-20251001", tokens: 3_000_000, pct: 30),
        ])
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("3 models"))
    }
}
