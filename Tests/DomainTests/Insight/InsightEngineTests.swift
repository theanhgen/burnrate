import Foundation
import Testing
@testable import Domain

@Suite
struct InsightEngineTests {

    // MARK: - Sorting

    @Test func `returns insights sorted by priority`() {
        // Create a context that triggers multiple generators at different priorities
        let now = Date()
        // Forecast: depleting in ~5h (high priority)
        let forecast = QuotaForecast.from(
            points: [
                (timestamp: now.addingTimeInterval(-3600), percentUsed: 40),
                (timestamp: now, percentUsed: 50),
            ],
            now: now
        )!

        // Trend: significant increase (medium priority)
        let current = SnapshotSummary(
            avgSession: 70, avgWeekly: 35, peakSession: 90,
            highUsageDays: 2, dataPointCount: 15, dayOfWeekDistribution: [:]
        )
        let previous = SnapshotSummary(
            avgSession: 45, avgWeekly: 22, peakSession: 70,
            highUsageDays: 0, dataPointCount: 15, dayOfWeekDistribution: [:]
        )

        let context = InsightContext(
            providerId: "claude",
            currentPeriod: current,
            previousPeriod: previous,
            forecast: forecast,
            now: now
        )

        let engine = InsightEngine()
        let insights = engine.evaluate(context: context)

        // Should have insights from multiple generators
        #expect(insights.count >= 2)

        // Should be sorted: first insight has highest (lowest rawValue) priority
        for i in 0..<(insights.count - 1) {
            #expect(insights[i].priority <= insights[i + 1].priority)
        }
    }

    // MARK: - Empty Context

    @Test func `handles empty context gracefully`() {
        let engine = InsightEngine()
        let insights = engine.evaluate(context: InsightContext())

        // Should not crash; may produce utilization insight for empty data
        for insight in insights {
            #expect(insight.providerId == nil)
        }
    }

    // MARK: - Custom Generators

    @Test func `uses custom generators when provided`() {
        struct StubGenerator: InsightGenerator {
            func generate(context: InsightContext) -> [UsageInsight] {
                [UsageInsight(
                    id: "stub",
                    category: .pace,
                    priority: .low,
                    title: "Stub",
                    detail: "Test",
                    symbolName: "circle",
                    severity: .neutral
                )]
            }
        }

        let engine = InsightEngine(generators: [StubGenerator()])
        let insights = engine.evaluate(context: InsightContext())

        #expect(insights.count == 1)
        #expect(insights[0].id == "stub")
    }
}
