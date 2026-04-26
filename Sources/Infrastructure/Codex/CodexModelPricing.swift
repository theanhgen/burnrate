import Foundation

/// Token pricing per 1M tokens for OpenAI models used by Codex.
/// Prices from OpenAI's published pricing.
enum CodexModelPricing {
    struct Price {
        let inputPer1M: Decimal
        let outputPer1M: Decimal
        let cachedInputPer1M: Decimal
    }

    /// Known model pricing (per 1M tokens in USD).
    /// Codex sessions don't expose the specific model per event,
    /// so we use "codex" as the default key mapped to GPT-5 pricing.
    static let prices: [String: Price] = [
        // GPT-5 (default Codex model)
        "codex": Price(inputPer1M: 2, outputPer1M: 8, cachedInputPer1M: 0.50),
        "gpt-5": Price(inputPer1M: 2, outputPer1M: 8, cachedInputPer1M: 0.50),

        // o3
        "o3": Price(inputPer1M: 2, outputPer1M: 8, cachedInputPer1M: 0.50),

        // o4-mini
        "o4-mini": Price(inputPer1M: 0.40, outputPer1M: 1.60, cachedInputPer1M: 0.10),
    ]

    /// Default pricing (GPT-5 level) for unknown models
    static let defaultPrice = Price(inputPer1M: 2, outputPer1M: 8, cachedInputPer1M: 0.50)

    /// Look up pricing for a model, falling back to default
    static func price(for model: String) -> Price {
        if let price = prices[model] { return price }

        for (key, price) in prices {
            if model.hasPrefix(key) || key.hasPrefix(model) { return price }
        }

        return defaultPrice
    }

    /// Calculate cost for a Codex token usage record.
    /// Reasoning output tokens are charged at the output rate.
    static func cost(for record: CodexTokenUsageRecord) -> Decimal {
        let p = defaultPrice // Codex doesn't expose model per event
        let inputCost = Decimal(record.inputTokens) / 1_000_000 * p.inputPer1M
        let outputCost = Decimal(record.outputTokens) / 1_000_000 * p.outputPer1M
        let cachedCost = Decimal(record.cachedInputTokens) / 1_000_000 * p.cachedInputPer1M
        return inputCost + outputCost + cachedCost
    }
}
