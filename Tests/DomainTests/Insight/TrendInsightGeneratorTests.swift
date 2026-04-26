import Foundation
import Testing
@testable import Domain

@Suite
struct TrendInsightGeneratorTests {
    private let generator = TrendInsightGenerator()

    private func makeSummary(avgSession: Double, dataPoints: Int = 10) -> SnapshotSummary {
        SnapshotSummary(
            avgSession: avgSession,
            avgWeekly: avgSession * 0.5,
            peakSession: Int(avgSession) + 10,
            highUsageDays: 0,
            dataPointCount: dataPoints,
            dayOfWeekDistribution: [:]
        )
    }

    private func makeContext(
        current: SnapshotSummary,
        previous: SnapshotSummary
    ) -> InsightContext {
        InsightContext(
            providerId: "claude",
            currentPeriod: current,
            previousPeriod: previous
        )
    }

    // MARK: - Insufficient Data

    @Test func `returns empty when current period has few data points`() {
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 60, dataPoints: 2),
            previous: makeSummary(avgSession: 50)
        ))
        #expect(insights.isEmpty)
    }

    @Test func `returns empty when previous period has few data points`() {
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 60),
            previous: makeSummary(avgSession: 50, dataPoints: 1)
        ))
        #expect(insights.isEmpty)
    }

    @Test func `returns empty when previous avg is zero`() {
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 60),
            previous: makeSummary(avgSession: 0)
        ))
        #expect(insights.isEmpty)
    }

    // MARK: - Stable (No Insight)

    @Test func `returns empty when change is below threshold`() {
        // 50 -> 55 = 10% change, below 15% threshold
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 55),
            previous: makeSummary(avgSession: 50)
        ))
        #expect(insights.isEmpty)
    }

    // MARK: - Upward Trend

    @Test func `generates caution insight when usage increases significantly`() {
        // 50 -> 65 = 30% increase
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 65),
            previous: makeSummary(avgSession: 50)
        ))

        #expect(insights.count == 1)
        #expect(insights[0].category == .trend)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].title.contains("up"))
        #expect(insights[0].title.contains("30%"))
    }

    // MARK: - Downward Trend

    @Test func `generates positive insight when usage decreases significantly`() {
        // 60 -> 45 = 25% decrease
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 45),
            previous: makeSummary(avgSession: 60)
        ))

        #expect(insights.count == 1)
        #expect(insights[0].category == .trend)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("down"))
        #expect(insights[0].title.contains("25%"))
    }

    // MARK: - Detail Content

    @Test func `includes previous and current averages in detail`() {
        let insights = generator.generate(context: makeContext(
            current: makeSummary(avgSession: 70),
            previous: makeSummary(avgSession: 50)
        ))

        #expect(insights[0].detail.contains("50%"))
        #expect(insights[0].detail.contains("70%"))
    }
}
