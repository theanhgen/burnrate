import Foundation

/// Generates subscription utilization assessment with actionable advice.
/// Replaces the simplistic "Low/Moderate/Good/Heavy" label.
public struct UtilizationInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        let summary = context.currentPeriod
        let pid = context.providerId ?? "all"

        guard summary.dataPointCount >= 5 else {
            return [UsageInsight(
                id: "util-insufficient-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Gathering data",
                detail: "Need more usage history for a utilization assessment.",
                providerId: context.providerId,
                symbolName: "clock",
                severity: .neutral
            )]
        }

        let avgWeekly = Int(summary.avgWeekly)
        let highDays = summary.highUsageDays

        switch avgWeekly {
        case ..<15:
            return [UsageInsight(
                id: "util-low-\(pid)",
                category: .utilization,
                priority: .medium,
                title: "Low utilization (\(avgWeekly)%)",
                detail: "You may be overpaying for this plan. Consider downgrading or using it more.",
                providerId: context.providerId,
                symbolName: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90",
                severity: .caution
            )]

        case 15..<40:
            return [UsageInsight(
                id: "util-moderate-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Moderate utilization (\(avgWeekly)%)",
                detail: "Using under half your quota on average. Room to get more value.",
                providerId: context.providerId,
                symbolName: "chart.bar",
                severity: .neutral
            )]

        case 40..<70:
            return [UsageInsight(
                id: "util-good-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Good utilization (\(avgWeekly)%)",
                detail: "Solid usage with comfortable headroom. Good balance.",
                providerId: context.providerId,
                symbolName: "checkmark.seal",
                severity: .positive
            )]

        case 70..<90 where highDays >= 3:
            return [UsageInsight(
                id: "util-heavy-limited-\(pid)",
                category: .utilization,
                priority: .medium,
                title: "Heavy usage, frequent limits",
                detail: "Hit 90%+ quota on \(highDays) days. Consider upgrading or adding a provider.",
                providerId: context.providerId,
                symbolName: "exclamationmark.circle",
                severity: .caution
            )]

        case 70...:
            return [UsageInsight(
                id: "util-heavy-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Strong utilization (\(avgWeekly)%)",
                detail: "Getting excellent value from your subscription.",
                providerId: context.providerId,
                symbolName: "star.fill",
                severity: .positive
            )]

        default:
            return []
        }
    }
}
