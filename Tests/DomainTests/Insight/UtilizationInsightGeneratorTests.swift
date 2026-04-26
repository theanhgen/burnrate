import Foundation
import Testing
@testable import Domain

@Suite
struct UtilizationInsightGeneratorTests {
    private let generator = UtilizationInsightGenerator()

    private func makeSummary(avgWeekly: Double, highDays: Int = 0, dataPoints: Int = 20) -> SnapshotSummary {
        SnapshotSummary(
            avgSession: avgWeekly * 1.5,
            avgWeekly: avgWeekly,
            peakSession: Int(avgWeekly) + 20,
            highUsageDays: highDays,
            dataPointCount: dataPoints,
            dayOfWeekDistribution: [:]
        )
    }

    private func makeContext(avgWeekly: Double, highDays: Int = 0, dataPoints: Int = 20) -> InsightContext {
        InsightContext(
            providerId: "claude",
            currentPeriod: makeSummary(avgWeekly: avgWeekly, highDays: highDays, dataPoints: dataPoints)
        )
    }

    // MARK: - Insufficient Data

    @Test func `returns gathering data when few data points`() {
        let insights = generator.generate(context: makeContext(avgWeekly: 50, dataPoints: 3))

        #expect(insights.count == 1)
        #expect(insights[0].title == "Gathering data")
        #expect(insights[0].severity == .neutral)
    }

    // MARK: - Low Utilization

    @Test func `generates caution for low utilization`() {
        let insights = generator.generate(context: makeContext(avgWeekly: 10))

        #expect(insights.count == 1)
        #expect(insights[0].category == .utilization)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].title.contains("Low"))
        #expect(insights[0].detail.contains("overpaying"))
    }

    // MARK: - Moderate Utilization

    @Test func `generates neutral for moderate utilization`() {
        let insights = generator.generate(context: makeContext(avgWeekly: 25))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .low)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("Moderate"))
    }

    // MARK: - Good Utilization

    @Test func `generates positive for good utilization`() {
        let insights = generator.generate(context: makeContext(avgWeekly: 55))

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("Good"))
    }

    // MARK: - Heavy with Frequent Limits

    @Test func `generates caution for heavy usage with frequent limits`() {
        let insights = generator.generate(context: makeContext(avgWeekly: 75, highDays: 4))

        #expect(insights.count == 1)
        #expect(insights[0].priority == .medium)
        #expect(insights[0].severity == .caution)
        #expect(insights[0].detail.contains("upgrading"))
    }

    // MARK: - Heavy without Limits

    @Test func `generates positive for heavy usage without frequent limits`() {
        let insights = generator.generate(context: makeContext(avgWeekly: 80, highDays: 1))

        #expect(insights.count == 1)
        #expect(insights[0].severity == .positive)
        #expect(insights[0].title.contains("Strong"))
    }
}
