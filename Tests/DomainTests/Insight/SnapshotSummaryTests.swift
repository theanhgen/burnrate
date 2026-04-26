import Foundation
import Testing
@testable import Domain

@Suite
struct SnapshotSummaryTests {

    // MARK: - Empty Input

    @Test func `empty snapshots returns empty summary`() {
        let summary = SnapshotSummary.from(snapshots: [])
        #expect(summary == .empty)
        #expect(summary.dataPointCount == 0)
        #expect(summary.avgSession == 0)
    }

    // MARK: - Averages

    @Test func `computes average session correctly`() {
        let snapshots = [
            (ts: Date().timeIntervalSince1970, session: 40, weekly: 20),
            (ts: Date().timeIntervalSince1970, session: 60, weekly: 30),
            (ts: Date().timeIntervalSince1970, session: 80, weekly: 40),
        ]
        let summary = SnapshotSummary.from(snapshots: snapshots)
        #expect(summary.avgSession == 60.0)
        #expect(summary.avgWeekly == 30.0)
    }

    @Test func `single snapshot averages to itself`() {
        let summary = SnapshotSummary.from(snapshots: [
            (ts: Date().timeIntervalSince1970, session: 75, weekly: 50),
        ])
        #expect(summary.avgSession == 75.0)
        #expect(summary.avgWeekly == 50.0)
        #expect(summary.dataPointCount == 1)
    }

    // MARK: - Peak

    @Test func `finds peak session usage`() {
        let snapshots = [
            (ts: Date().timeIntervalSince1970, session: 40, weekly: 20),
            (ts: Date().timeIntervalSince1970, session: 95, weekly: 60),
            (ts: Date().timeIntervalSince1970, session: 70, weekly: 40),
        ]
        let summary = SnapshotSummary.from(snapshots: snapshots)
        #expect(summary.peakSession == 95)
    }

    // MARK: - High Usage Days

    @Test func `counts distinct days above 90 percent`() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000) // some fixed date
        let day2 = day1.addingTimeInterval(86400) // next day

        let snapshots = [
            (ts: day1.timeIntervalSince1970, session: 95, weekly: 50),
            (ts: day1.timeIntervalSince1970 + 3600, session: 92, weekly: 50), // same day
            (ts: day2.timeIntervalSince1970, session: 91, weekly: 50),
        ]
        let summary = SnapshotSummary.from(snapshots: snapshots)
        #expect(summary.highUsageDays == 2)
    }

    @Test func `does not count days at exactly 90 percent`() {
        let snapshots = [
            (ts: Date().timeIntervalSince1970, session: 90, weekly: 50),
        ]
        let summary = SnapshotSummary.from(snapshots: snapshots)
        #expect(summary.highUsageDays == 0)
    }

    // MARK: - Day-of-Week Distribution

    @Test func `computes weekday distribution`() {
        // Create dates on known weekdays
        let calendar = Calendar.current
        // Find a known Monday
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 6 // Monday
        components.hour = 12
        let monday = calendar.date(from: components)!

        // Friday is 4 days later
        let friday = calendar.date(byAdding: .day, value: 4, to: monday)!

        let snapshots = [
            (ts: monday.timeIntervalSince1970, session: 80, weekly: 40),
            (ts: friday.timeIntervalSince1970, session: 20, weekly: 10),
        ]
        let summary = SnapshotSummary.from(snapshots: snapshots)

        // Monday = weekday 2, Friday = weekday 6
        #expect(summary.dayOfWeekDistribution[2] == 80.0)
        #expect(summary.dayOfWeekDistribution[6] == 20.0)
    }

    @Test func `averages multiple snapshots on same weekday`() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 6 // Monday
        components.hour = 12
        let monday1 = calendar.date(from: components)!
        let monday2 = calendar.date(byAdding: .weekOfYear, value: 1, to: monday1)!

        let snapshots = [
            (ts: monday1.timeIntervalSince1970, session: 60, weekly: 30),
            (ts: monday2.timeIntervalSince1970, session: 80, weekly: 50),
        ]
        let summary = SnapshotSummary.from(snapshots: snapshots)

        // Monday avg: (60 + 80) / 2 = 70
        #expect(summary.dayOfWeekDistribution[2] == 70.0)
    }

    // MARK: - Data Point Count

    @Test func `reports correct data point count`() {
        let snapshots = (0..<10).map { i in
            (ts: Date().timeIntervalSince1970 + Double(i), session: 50, weekly: 25)
        }
        let summary = SnapshotSummary.from(snapshots: snapshots)
        #expect(summary.dataPointCount == 10)
    }
}
