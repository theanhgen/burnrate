import Foundation

/// Generates insights from the current usage pace relative to expected consumption.
/// Wraps existing UsagePace/burnRate domain logic into human-readable insights.
public struct PaceInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        let pid = context.providerId ?? "all"

        // Find the most relevant quota (prefer session, fall back to weekly)
        guard let quota = context.liveQuotas.first(where: { $0.quotaType == .session })
                ?? context.liveQuotas.first else {
            return []
        }

        guard let pacePercent = quota.pacePercent else { return [] }
        let absDelta = Int(abs(pacePercent))

        switch quota.pace {
        case .ahead where absDelta > 20:
            return [UsageInsight(
                id: "pace-hot-\(pid)",
                category: .pace,
                priority: .high,
                title: "Running hot",
                detail: "Burning \(absDelta)% faster than sustainable. Consider pacing.",
                providerId: context.providerId,
                symbolName: "hare.fill",
                severity: .caution
            )]

        case .ahead:
            return [UsageInsight(
                id: "pace-ahead-\(pid)",
                category: .pace,
                priority: .medium,
                title: "Slightly ahead of pace",
                detail: "\(absDelta)% above expected usage for this point in the period.",
                providerId: context.providerId,
                symbolName: "hare.fill",
                severity: .caution
            )]

        case .onPace:
            return [UsageInsight(
                id: "pace-ok-\(pid)",
                category: .pace,
                priority: .low,
                title: "Right on track",
                detail: "Usage is matching the expected pace for this period.",
                providerId: context.providerId,
                symbolName: "equal.circle.fill",
                severity: .positive
            )]

        case .behind:
            return [UsageInsight(
                id: "pace-behind-\(pid)",
                category: .pace,
                priority: .low,
                title: "Room to spare",
                detail: "\(absDelta)% below expected usage. Plenty of headroom.",
                providerId: context.providerId,
                symbolName: "tortoise.fill",
                severity: .positive
            )]

        case .unknown:
            return []
        }
    }
}
