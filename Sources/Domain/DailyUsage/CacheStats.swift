import Foundation

/// Cache token statistics for estimating cost savings.
/// Cache reads are cheaper than fresh input tokens — the difference is the savings.
public struct CacheStats: Sendable, Equatable {
    /// Tokens read from the prompt cache (billed at reduced rate)
    public let cacheReadTokens: Int
    /// Tokens written to the prompt cache (billed at premium rate)
    public let cacheCreationTokens: Int
    /// Estimated USD saved by cache reads vs. full-price input tokens
    public let estimatedSavings: Decimal

    public init(
        cacheReadTokens: Int,
        cacheCreationTokens: Int,
        estimatedSavings: Decimal
    ) {
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.estimatedSavings = estimatedSavings
    }

    /// Total cache tokens (read + creation)
    public var totalCacheTokens: Int {
        cacheReadTokens + cacheCreationTokens
    }

    /// Cache read ratio: what fraction of cache tokens are reads (0-1)
    public var cacheReadRatio: Double {
        guard totalCacheTokens > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(totalCacheTokens)
    }

    /// Formatted savings string (e.g., "$12.50")
    public var formattedSavings: String {
        let amount = NSDecimalNumber(decimal: estimatedSavings).doubleValue
        return String(format: "$%.2f", amount)
    }
}
