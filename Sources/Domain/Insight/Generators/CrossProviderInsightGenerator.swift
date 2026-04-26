import Foundation

/// Compares quota usage across providers. Only fires in the "All" tab (providerId == nil).
/// Helps users see which provider dominates their usage.
public struct CrossProviderInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        // Only for cross-provider view
        guard context.providerId == nil else { return [] }
        guard !context.liveQuotas.isEmpty else { return [] }

        // Group session quotas by provider, take session % used for each
        var providerUsage: [String: Double] = [:]
        for quota in context.liveQuotas where quota.quotaType == .session {
            providerUsage[quota.providerId] = quota.percentUsed
        }

        // Fall back to weekly if no session quotas
        if providerUsage.isEmpty {
            for quota in context.liveQuotas where quota.quotaType == .weekly {
                if providerUsage[quota.providerId] == nil {
                    providerUsage[quota.providerId] = quota.percentUsed
                }
            }
        }

        // Need at least 2 providers to compare
        guard providerUsage.count >= 2 else { return [] }

        let totalUsage = providerUsage.values.reduce(0, +)
        guard totalUsage > 0 else { return [] }

        // Find the dominant provider
        guard let (topProvider, topUsage) = providerUsage.max(by: { $0.value < $1.value }) else {
            return []
        }

        let topShare = Int(topUsage / totalUsage * 100)

        if topShare >= 70 {
            return [UsageInsight(
                id: "cross-provider-dominant",
                category: .pattern,
                priority: .medium,
                title: "\(topProvider.capitalized) is \(topShare)% of usage",
                detail: "Across \(providerUsage.count) providers, \(topProvider.capitalized) dominates your quota consumption.",
                symbolName: "chart.pie",
                severity: .neutral
            )]
        }

        return [UsageInsight(
            id: "cross-provider-balanced",
            category: .pattern,
            priority: .low,
            title: "Usage spread across \(providerUsage.count) providers",
            detail: "No single provider dominates — balanced distribution.",
            symbolName: "chart.pie",
            severity: .positive
        )]
    }
}
