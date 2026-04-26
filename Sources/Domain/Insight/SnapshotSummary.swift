import Foundation

/// Period statistics computed from raw usage snapshots.
/// Used by insight generators to compare current vs previous periods.
public struct SnapshotSummary: Sendable, Equatable {
    /// Average session usage % across the period
    public let avgSession: Double
    /// Average weekly usage % across the period
    public let avgWeekly: Double
    /// Peak session usage % observed
    public let peakSession: Int
    /// Number of distinct days with session usage > 90%
    public let highUsageDays: Int
    /// Total snapshot count in this period
    public let dataPointCount: Int
    /// Average session usage % by weekday (1=Sunday .. 7=Saturday)
    public let dayOfWeekDistribution: [Int: Double]

    public init(
        avgSession: Double,
        avgWeekly: Double,
        peakSession: Int,
        highUsageDays: Int,
        dataPointCount: Int,
        dayOfWeekDistribution: [Int: Double]
    ) {
        self.avgSession = avgSession
        self.avgWeekly = avgWeekly
        self.peakSession = peakSession
        self.highUsageDays = highUsageDays
        self.dataPointCount = dataPointCount
        self.dayOfWeekDistribution = dayOfWeekDistribution
    }

    /// Empty summary for when no data is available.
    public static let empty = SnapshotSummary(
        avgSession: 0, avgWeekly: 0, peakSession: 0,
        highUsageDays: 0, dataPointCount: 0, dayOfWeekDistribution: [:]
    )

    /// Computes a summary from raw snapshot tuples.
    /// - Parameter snapshots: Array of (timestamp, session%, weekly%) tuples.
    public static func from(
        snapshots: [(ts: TimeInterval, session: Int, weekly: Int)]
    ) -> SnapshotSummary {
        guard !snapshots.isEmpty else { return .empty }

        let calendar = Calendar.current

        let avgSession = Double(snapshots.map(\.session).reduce(0, +)) / Double(snapshots.count)
        let avgWeekly = Double(snapshots.map(\.weekly).reduce(0, +)) / Double(snapshots.count)
        let peakSession = snapshots.map(\.session).max() ?? 0

        // Count distinct calendar days with session > 90%
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let highDays = Set(
            snapshots.filter { $0.session > 90 }
                .map { dateFormatter.string(from: Date(timeIntervalSince1970: $0.ts)) }
        ).count

        // Day-of-week distribution: group by weekday, average session%
        var weekdayTotals: [Int: (sum: Int, count: Int)] = [:]
        for snapshot in snapshots {
            let date = Date(timeIntervalSince1970: snapshot.ts)
            let weekday = calendar.component(.weekday, from: date)
            let entry = weekdayTotals[weekday, default: (sum: 0, count: 0)]
            weekdayTotals[weekday] = (sum: entry.sum + snapshot.session, count: entry.count + 1)
        }
        let distribution = weekdayTotals.mapValues { Double($0.sum) / Double($0.count) }

        return SnapshotSummary(
            avgSession: avgSession,
            avgWeekly: avgWeekly,
            peakSession: peakSession,
            highUsageDays: highDays,
            dataPointCount: snapshots.count,
            dayOfWeekDistribution: distribution
        )
    }
}
