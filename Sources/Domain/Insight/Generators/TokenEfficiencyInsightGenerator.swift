import Foundation

/// Analyzes the input-to-output token ratio to characterize workload type.
/// High output = generation-heavy (writing code). High input = context-heavy (large codebases).
public struct TokenEfficiencyInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        guard let report = context.dailyReport else { return [] }

        let breakdown = report.today.modelBreakdown
        guard !breakdown.isEmpty else { return [] }

        let pid = context.providerId ?? "all"
        let totalInput = breakdown.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = breakdown.reduce(0) { $0 + $1.outputTokens }

        guard totalInput > 0 else { return [] }

        let ratio = Double(totalOutput) / Double(totalInput)
        let ratioStr = String(format: "%.0f", ratio)

        if ratio > 5 {
            return [UsageInsight(
                id: "token-efficiency-gen-heavy-\(pid)",
                category: .pattern,
                priority: .low,
                title: "Generation-heavy: \(ratioStr)x output ratio",
                detail: "Producing \(ratioStr)x more output than input — heavy code generation.",
                providerId: context.providerId,
                symbolName: "arrow.up.doc",
                severity: .neutral
            )]
        }

        if ratio >= 2 {
            return [UsageInsight(
                id: "token-efficiency-balanced-\(pid)",
                category: .pattern,
                priority: .low,
                title: "Balanced \(ratioStr)x output-to-input ratio",
                detail: "Mix of context reading and code generation.",
                providerId: context.providerId,
                symbolName: "arrow.left.arrow.right",
                severity: .neutral
            )]
        }

        return [UsageInsight(
            id: "token-efficiency-context-heavy-\(pid)",
            category: .pattern,
            priority: .low,
            title: "Context-heavy workload",
            detail: "High input token use — large codebases or long conversations.",
            providerId: context.providerId,
            symbolName: "arrow.down.doc",
            severity: .neutral
        )]
    }
}
