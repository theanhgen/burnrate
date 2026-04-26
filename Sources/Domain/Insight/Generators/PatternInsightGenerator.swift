import Foundation

/// Generates insights from day-of-week usage patterns.
/// Only produces insights when there is meaningful variance across weekdays.
public struct PatternInsightGenerator: InsightGenerator, Sendable {

    /// Minimum standard deviation in day-of-week averages to consider the pattern meaningful.
    static let significantVarianceThreshold: Double = 10.0

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        let distribution = context.currentPeriod.dayOfWeekDistribution
        let pid = context.providerId ?? "all"

        // Need at least 3 distinct weekdays to detect a pattern
        guard distribution.count >= 3 else { return [] }

        let values = Array(distribution.values)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        let stdDev = variance.squareRoot()

        guard stdDev >= Self.significantVarianceThreshold else { return [] }

        // Find the heaviest day
        guard let (heaviestWeekday, heaviestAvg) = distribution.max(by: { $0.value < $1.value }) else {
            return []
        }

        let dayName = Self.weekdayName(heaviestWeekday)

        return [UsageInsight(
            id: "pattern-heavy-day-\(pid)",
            category: .pattern,
            priority: .low,
            title: "\(dayName)s are your heaviest",
            detail: "Average session usage on \(dayName)s is \(Int(heaviestAvg))%.",
            providerId: context.providerId,
            symbolName: "calendar.badge.clock",
            severity: .neutral
        )]
    }

    private static func weekdayName(_ weekday: Int) -> String {
        // Calendar weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        switch weekday {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: "Day \(weekday)"
        }
    }
}
