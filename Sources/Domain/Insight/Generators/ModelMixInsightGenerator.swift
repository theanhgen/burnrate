import Foundation

/// Generates insights about which AI models consume the most budget.
/// Only produces insights when per-model breakdown data is available (Claude).
public struct ModelMixInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        guard let report = context.dailyReport else { return [] }

        let breakdown = report.today.modelBreakdown
        guard !breakdown.isEmpty else { return [] }

        let pid = context.providerId ?? "all"

        if breakdown.count == 1 {
            let model = breakdown[0]
            return [UsageInsight(
                id: "model-mix-single-\(pid)",
                category: .pattern,
                priority: .low,
                title: "All tokens on \(model.displayName)",
                detail: "\(model.formattedCost) across \(model.totalTokens.formatted()) tokens today.",
                providerId: context.providerId,
                symbolName: "cpu",
                severity: .neutral
            )]
        }

        let top = breakdown[0] // Already sorted by totalTokens descending
        let topPct = Int(top.percentage)

        if topPct >= 60 {
            return [UsageInsight(
                id: "model-mix-dominant-\(pid)",
                category: .pattern,
                priority: .medium,
                title: "\(top.displayName) handles \(topPct)% of work",
                detail: "\(top.formattedCost) on \(top.displayName) today. Using \(breakdown.count) models total.",
                providerId: context.providerId,
                symbolName: "cpu",
                severity: .neutral
            )]
        }

        if breakdown.count >= 3 {
            return [UsageInsight(
                id: "model-mix-diverse-\(pid)",
                category: .pattern,
                priority: .low,
                title: "Using \(breakdown.count) models",
                detail: "Distributing work across models for cost optimization.",
                providerId: context.providerId,
                symbolName: "cpu",
                severity: .positive
            )]
        }

        return []
    }
}
