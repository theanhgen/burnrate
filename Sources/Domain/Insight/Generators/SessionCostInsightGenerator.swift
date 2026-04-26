import Foundation

/// Generates insights about average cost per coding session.
/// Helps users understand their per-session spending.
public struct SessionCostInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        guard let report = context.dailyReport else { return [] }

        let today = report.today
        guard today.sessionCount > 0, today.totalCost > 0 else { return [] }

        let pid = context.providerId ?? "all"
        let avgCost = today.totalCost / Decimal(today.sessionCount)
        let avgAmount = NSDecimalNumber(decimal: avgCost).doubleValue
        let formatted = String(format: "$%.0f", avgAmount)

        if avgAmount >= 10 {
            return [UsageInsight(
                id: "session-cost-heavy-\(pid)",
                category: .utilization,
                priority: .medium,
                title: "Averaging \(formatted)/session",
                detail: "\(today.sessionCount) sessions today, \(today.formattedCost) total. Heavy sessions.",
                providerId: context.providerId,
                symbolName: "dollarsign.circle",
                severity: .caution
            )]
        }

        if avgAmount >= 3 {
            return [UsageInsight(
                id: "session-cost-moderate-\(pid)",
                category: .utilization,
                priority: .low,
                title: "~\(formatted) per session",
                detail: "\(today.sessionCount) sessions today, \(today.formattedCost) total.",
                providerId: context.providerId,
                symbolName: "dollarsign.circle",
                severity: .neutral
            )]
        }

        return [UsageInsight(
            id: "session-cost-light-\(pid)",
            category: .utilization,
            priority: .low,
            title: "Light sessions (~\(formatted) each)",
            detail: "\(today.sessionCount) sessions today, \(today.formattedCost) total.",
            providerId: context.providerId,
            symbolName: "dollarsign.circle",
            severity: .positive
        )]
    }
}
