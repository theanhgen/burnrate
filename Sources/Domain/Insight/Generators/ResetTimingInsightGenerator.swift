import Foundation

/// Advises on quota reset timing — push hard before reset, don't waste expiring quota.
/// Philosophy: maximize usage of quota that's about to refill.
public struct ResetTimingInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        let pid = context.providerId ?? "all"

        // Prefer session quota, fall back to weekly
        guard let quota = context.liveQuotas.first(where: { $0.quotaType == .session })
                ?? context.liveQuotas.first,
              let timeUntilReset = quota.timeUntilReset else {
            return []
        }

        let hoursUntilReset = timeUntilReset / 3600
        let remaining = Int(quota.percentRemaining)
        let minsUntilReset = max(1, Int(timeUntilReset / 60))

        // Reset in <1h
        if hoursUntilReset < 1 {
            if quota.isDepleted {
                // Depleted but resetting soon — hang tight
                return [UsageInsight(
                    id: "reset-imminent-depleted-\(pid)",
                    category: .depletion,
                    priority: .medium,
                    title: "Refreshes in \(minsUntilReset)m",
                    detail: "Quota is depleted but resets soon. Hang tight.",
                    providerId: context.providerId,
                    symbolName: "clock.arrow.circlepath",
                    severity: .neutral
                )]
            }

            if remaining > 20 {
                // Significant quota expiring soon — push hard
                return [UsageInsight(
                    id: "reset-imminent-use-it-\(pid)",
                    category: .pace,
                    priority: .high,
                    title: "Use it — \(remaining)% left, resets in \(minsUntilReset)m",
                    detail: "Quota refills soon. Push hard before it resets.",
                    providerId: context.providerId,
                    symbolName: "bolt.fill",
                    severity: .positive
                )]
            }
        }

        // Reset in <2h with lots of quota left
        if hoursUntilReset < 2 && remaining > 40 {
            let timeDesc = minsUntilReset >= 60
                ? "\(minsUntilReset / 60)h \(minsUntilReset % 60)m"
                : "\(minsUntilReset)m"
            return [UsageInsight(
                id: "reset-soon-plenty-\(pid)",
                category: .pace,
                priority: .medium,
                title: "\(remaining)% left, resets in \(timeDesc)",
                detail: "Plenty of quota before reset — use it or lose it.",
                providerId: context.providerId,
                symbolName: "bolt.fill",
                severity: .positive
            )]
        }

        return []
    }
}
