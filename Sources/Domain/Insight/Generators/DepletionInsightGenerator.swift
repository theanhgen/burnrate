import Foundation

/// Generates insights from quota depletion forecasts.
/// Priority: critical when depleting soon, low when sustainable.
public struct DepletionInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        guard let forecast = context.forecast else { return [] }

        let pid = context.providerId ?? "all"

        guard let depletion = forecast.estimatedDepletionDate else {
            // No depletion expected
            guard forecast.burnRatePerHour > 0 else { return [] }
            return [UsageInsight(
                id: "depletion-ok-\(pid)",
                category: .depletion,
                priority: .low,
                title: "Quota sustainable",
                detail: "At current pace, no depletion expected this period.",
                providerId: context.providerId,
                symbolName: "checkmark.circle",
                severity: .positive
            )]
        }

        let hoursRemaining = depletion.timeIntervalSince(context.now) / 3600

        if hoursRemaining <= 0 {
            // Already depleted
            let resetInfo = context.liveQuotas.first?.resetDescription ?? ""
            return [UsageInsight(
                id: "depletion-depleted-\(pid)",
                category: .depletion,
                priority: .critical,
                title: "Quota depleted",
                detail: resetInfo.isEmpty
                    ? "Session quota is exhausted."
                    : "Session quota is exhausted. \(resetInfo).",
                providerId: context.providerId,
                symbolName: "exclamationmark.triangle.fill",
                severity: .urgent
            )]
        }

        if hoursRemaining < 1 {
            let mins = max(1, Int(hoursRemaining * 60))
            return [UsageInsight(
                id: "depletion-imminent-\(pid)",
                category: .depletion,
                priority: .critical,
                title: "Depletes in ~\(mins)m",
                detail: String(format: "At %.1f%%/hr burn rate, quota runs out very soon.", forecast.burnRatePerHour),
                providerId: context.providerId,
                symbolName: "exclamationmark.triangle.fill",
                severity: .urgent
            )]
        }

        if hoursRemaining < 8 {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let timeStr = timeFormatter.string(from: depletion)
            return [UsageInsight(
                id: "depletion-soon-\(pid)",
                category: .depletion,
                priority: .high,
                title: "Depletes in ~\(Int(hoursRemaining))h",
                detail: "On track to hit the limit by \(timeStr).",
                providerId: context.providerId,
                symbolName: "chart.line.downtrend.xyaxis",
                severity: .caution
            )]
        }

        // Depletion is >8h away — informational
        let hours = Int(hoursRemaining)
        return [UsageInsight(
            id: "depletion-distant-\(pid)",
            category: .depletion,
            priority: .low,
            title: "~\(hours)h until limit",
            detail: String(format: "Burn rate: %.1f%%/hr. Plenty of runway.", forecast.burnRatePerHour),
            providerId: context.providerId,
            symbolName: "chart.line.downtrend.xyaxis",
            severity: .neutral
        )]
    }
}
