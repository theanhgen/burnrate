import Foundation

/// Generates insights by comparing current 7-day period against the previous 7-day period.
/// Only produces insights when the change is meaningful (>15% delta).
public struct TrendInsightGenerator: InsightGenerator, Sendable {

    /// Minimum percentage change to trigger a trend insight.
    static let significantChangeThreshold: Double = 15.0

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        let current = context.currentPeriod
        let previous = context.previousPeriod
        let pid = context.providerId ?? "all"

        // Need meaningful data in both periods
        guard current.dataPointCount >= 3, previous.dataPointCount >= 3 else { return [] }
        guard previous.avgSession > 0 else { return [] }

        let changePercent = ((current.avgSession - previous.avgSession) / previous.avgSession) * 100
        let absChange = Int(abs(changePercent))

        guard Double(absChange) >= Self.significantChangeThreshold else { return [] }

        if changePercent > 0 {
            return [UsageInsight(
                id: "trend-up-\(pid)",
                category: .trend,
                priority: .medium,
                title: "Usage up \(absChange)% vs last week",
                detail: "Average session usage rose from \(Int(previous.avgSession))% to \(Int(current.avgSession))%.",
                providerId: context.providerId,
                symbolName: "arrow.up.right",
                severity: .caution
            )]
        } else {
            return [UsageInsight(
                id: "trend-down-\(pid)",
                category: .trend,
                priority: .medium,
                title: "Usage down \(absChange)% from last week",
                detail: "Average session usage dropped from \(Int(previous.avgSession))% to \(Int(current.avgSession))%.",
                providerId: context.providerId,
                symbolName: "arrow.down.right",
                severity: .positive
            )]
        }
    }
}
