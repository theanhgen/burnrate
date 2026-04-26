import Foundation

/// Generates insights about prompt cache efficiency and cost savings.
/// Only produces insights when cache stats are available (Claude).
public struct CacheEfficiencyInsightGenerator: InsightGenerator, Sendable {

    public init() {}

    public func generate(context: InsightContext) -> [UsageInsight] {
        guard let report = context.dailyReport,
              let cache = report.today.cacheStats else { return [] }

        let pid = context.providerId ?? "all"

        let savings = NSDecimalNumber(decimal: cache.estimatedSavings).doubleValue

        if savings >= 5 {
            return [UsageInsight(
                id: "cache-savings-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Cache saved \(cache.formattedSavings) today",
                detail: String(format: "%.0f%% of input tokens served from cache.", cache.cacheReadRatio * 100),
                providerId: context.providerId,
                symbolName: "arrow.triangle.2.circlepath",
                severity: .positive
            )]
        }

        let readPct = Int(cache.cacheReadRatio * 100)
        if readPct >= 50 {
            return [UsageInsight(
                id: "cache-efficiency-\(pid)",
                category: .utilization,
                priority: .low,
                title: "\(readPct)% cache hit rate",
                detail: "Good cache efficiency — saving on input token costs.",
                providerId: context.providerId,
                symbolName: "arrow.triangle.2.circlepath",
                severity: .positive
            )]
        }

        if cache.totalCacheTokens > 0 && readPct < 10 {
            return [UsageInsight(
                id: "cache-low-\(pid)",
                category: .utilization,
                priority: .low,
                title: "Minimal caching today",
                detail: "Only \(readPct)% of cache tokens are reads. Most work is fresh context.",
                providerId: context.providerId,
                symbolName: "arrow.triangle.2.circlepath",
                severity: .neutral
            )]
        }

        return []
    }
}
