import Foundation
import Testing
@testable import Domain

@Suite
struct SessionCostInsightGeneratorTests {
    private let generator = SessionCostInsightGenerator()

    private func makeReport(cost: Decimal, sessions: Int) -> DailyUsageReport {
        DailyUsageReport(
            today: DailyUsageStat(
                date: Date(),
                totalCost: cost,
                totalTokens: 5_000_000,
                workingTime: 7200,
                sessionCount: sessions
            ),
            previous: .empty(for: Date().addingTimeInterval(-86400))
        )
    }

    // MARK: - No Data

    @Test func `returns empty when no daily report`() {
        let context = InsightContext(providerId: "claude")
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when zero sessions`() {
        let report = makeReport(cost: 20, sessions: 0)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    @Test func `returns empty when zero cost`() {
        let report = makeReport(cost: 0, sessions: 3)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        #expect(generator.generate(context: context).isEmpty)
    }

    // MARK: - Heavy Sessions (>$10/session)

    @Test func `generates caution for heavy sessions`() {
        // $42 across 3 sessions = $14/session
        let report = makeReport(cost: 42, sessions: 3)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].title.contains("$14"))
    }

    // MARK: - Moderate Sessions ($3-10/session)

    @Test func `generates neutral for moderate sessions`() {
        // $18 across 3 sessions = $6/session
        let report = makeReport(cost: 18, sessions: 3)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("$6"))
    }

    // MARK: - Light Sessions (<$3/session)

    @Test func `generates positive for light sessions`() {
        // $6 across 3 sessions = $2/session
        let report = makeReport(cost: 6, sessions: 3)
        let context = InsightContext(providerId: "claude", dailyReport: report)
        let insights = generator.generate(context: context)

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("Light"))
    }
}
