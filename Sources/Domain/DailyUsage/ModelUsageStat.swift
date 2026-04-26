import Foundation

/// Per-model token and cost breakdown for a single day.
/// Enables insights about which models consume the most budget.
public struct ModelUsageStat: Sendable, Equatable, Identifiable {
    /// Model identifier (e.g., "claude-opus-4-6")
    public let model: String
    /// Input tokens consumed by this model
    public let inputTokens: Int
    /// Output tokens produced by this model
    public let outputTokens: Int
    /// Total tokens (input + output)
    public let totalTokens: Int
    /// USD cost attributed to this model
    public let cost: Decimal
    /// Share of total tokens across all models (0-100)
    public let percentage: Double

    public var id: String { model }

    public init(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        cost: Decimal,
        percentage: Double
    ) {
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cost = cost
        self.percentage = percentage
    }

    /// Human-readable model name (strips "claude-" prefix, e.g., "opus-4-6")
    public var displayName: String {
        model
            .replacingOccurrences(of: "claude-", with: "")
            .split(separator: "-")
            .prefix(2)
            .joined(separator: " ")
            .capitalized
    }

    /// Formatted cost string (e.g., "$14.26")
    public var formattedCost: String {
        let amount = NSDecimalNumber(decimal: cost).doubleValue
        return String(format: "$%.2f", amount)
    }
}
