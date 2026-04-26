import Foundation

/// Projects monthly spending based on recent daily cost data.
/// Uses today + yesterday average to smooth out single-day spikes.
public struct CostProjectionInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        guard let report = context.dailyReport else { return [] }

        let pid = context.providerId ?? "all"
        let todayCost = report.today.totalCost
        let prevCost = report.previous.totalCost

        // Need at least today's cost to project
        guard todayCost > 0 else { return [] }

        let dailyAvg: Decimal
        if prevCost > 0 {
            dailyAvg = (todayCost + prevCost) / 2
        } else {
            dailyAvg = todayCost
        }

        let monthlyProjection = dailyAvg * 30
        let amount = NSDecimalNumber(decimal: monthlyProjection).intValue
        let formatted = "$\(amount)"

        if amount >= 500 {
            return [UsageInsight(
                id: "cost-projection-high-\(pid)",
                category: .utilization,
                priority: .medium,
                title: "On track for ~\(formatted)/month",
                detail: "Based on recent daily spending of ~\(formatCost(dailyAvg))/day.",
                providerId: context.providerId,
                symbolName: "chart.line.uptrend.xyaxis",
                severity: .caution
            )]
        }

        if amount >= 100 {
            return [UsageInsight(
                id: "cost-projection-moderate-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Monthly pace: ~\(formatted)",
                detail: "Averaging ~\(formatCost(dailyAvg))/day across recent sessions.",
                providerId: context.providerId,
                symbolName: "chart.line.uptrend.xyaxis",
                severity: .neutral
            )]
        }

        return [UsageInsight(
            id: "cost-projection-light-\(pid)",
            category: .utilization,
            priority: .low,
            title: "Light month — ~\(formatted) pace",
            detail: "Averaging ~\(formatCost(dailyAvg))/day.",
            providerId: context.providerId,
            symbolName: "chart.line.uptrend.xyaxis",
            severity: .positive
        )]
    }

    private func formatCost(_ cost: Decimal) -> String {
        let amount = NSDecimalNumber(decimal: cost).doubleValue
        return String(format: "$%.0f", amount)
    }
}
