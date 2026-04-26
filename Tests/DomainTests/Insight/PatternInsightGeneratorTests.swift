import Foundation
import Testing
@testable import Domain

@Suite
struct PatternInsightGeneratorTests {
    private let generator = PatternInsightGenerator()

    private func makeSummary(distribution: [Int: Double]) -> SnapshotSummary {
        SnapshotSummary(
            avgSession: 50,
            avgWeekly: 25,
            peakSession: 90,
            highUsageDays: 2,
            dataPointCount: 20,
            dayOfWeekDistribution: distribution
        )
    }

    private func makeContext(distribution: [Int: Double]) -> InsightContext {
        InsightContext(
            providerId: "claude",
            currentPeriod: makeSummary(distribution: distribution)
        )
    }

    // MARK: - Insufficient Data

    @Test func `returns empty when fewer than three weekdays`() {
        let insights = generator.generate(context: makeContext(distribution: [
            2: 80.0, // Monday
            6: 20.0, // Friday
        ]))
        #expect(insights.isEmpty)
    }

    // MARK: - Low Variance (No Pattern)

    @Test func `returns empty when variance is low`() {
        // All days around 50% — std dev < 10%
        let insights = generator.generate(context: makeContext(distribution: [
            1: 48.0, 2: 52.0, 3: 50.0, 4: 51.0, 5: 49.0, 6: 50.0, 7: 50.0,
        ]))
        #expect(insights.isEmpty)
    }

    // MARK: - Significant Pattern

    @Test func `identifies heaviest day when variance is significant`() {
        // Wednesday (4) is clearly heaviest
        let insights = generator.generate(context: makeContext(distribution: [
            2: 40.0, // Mon
            3: 35.0, // Tue
            4: 85.0, // Wed (heaviest)
            5: 45.0, // Thu
            6: 30.0, // Fri
        ]))

        #expect(insights.count == 1)
        #expect(insights[0].category == .pattern)
        #expect(insights[0].priority == .low)
        #expect(insights[0].severity == .neutral)
        #expect(insights[0].title.contains("Wednesday"))
    }

    @Test func `includes average in detail`() {
        let insights = generator.generate(context: makeContext(distribution: [
            2: 40.0, 3: 35.0, 4: 85.0, 5: 45.0, 6: 30.0,
        ]))

        #expect(insights[0].detail.contains("85%"))
    }

    // MARK: - Different Days

    @Test func `identifies Friday as heaviest when applicable`() {
        let insights = generator.generate(context: makeContext(distribution: [
            2: 30.0, // Mon
            3: 25.0, // Tue
            4: 35.0, // Wed
            5: 20.0, // Thu
            6: 90.0, // Fri (heaviest)
        ]))

        #expect(insights[0].title.contains("Friday"))
    }
}
