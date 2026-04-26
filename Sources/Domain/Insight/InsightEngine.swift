import Foundation

/// Protocol for composable insight generators.
/// Each generator evaluates one aspect of usage (depletion, pace, trend, etc.)
/// and returns zero or more insights.
public protocol InsightGenerator: Sendable {
    func generate(context: InsightContext) -> [UsageInsight]
}

/// Orchestrates multiple generators, collects results, and sorts by priority.
public struct InsightEngine: Sendable {
    private let generators: [any InsightGenerator]

    public init(generators: [any InsightGenerator] = Self.defaultGenerators) {
        self.generators = generators
    }

    public static let defaultGenerators: [any InsightGenerator] = [
        DepletionInsightGenerator(),
        PaceInsightGenerator(),
        TrendInsightGenerator(),
        PatternInsightGenerator(),
        UtilizationInsightGenerator(),
        ModelMixInsightGenerator(),
        CacheEfficiencyInsightGenerator(),
        SessionCostInsightGenerator(),
        CostProjectionInsightGenerator(),
        ResetTimingInsightGenerator(),
        CrossProviderInsightGenerator(),
        TokenEfficiencyInsightGenerator(),
    ]

    /// Evaluates all generators and returns insights sorted by priority (critical first).
    public func evaluate(context: InsightContext) -> [UsageInsight] {
        generators
            .flatMap { $0.generate(context: context) }
            .sorted { $0.priority < $1.priority }
    }
}
