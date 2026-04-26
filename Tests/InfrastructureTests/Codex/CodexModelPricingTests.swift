import Foundation
import Testing
@testable import Infrastructure

@Suite
struct CodexModelPricingTests {
    @Test func `calculates cost for typical token usage`() {
        let record = CodexTokenUsageRecord(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            cachedInputTokens: 0,
            reasoningOutputTokens: 0,
            timestamp: Date()
        )
        let cost = CodexModelPricing.cost(for: record)
        // $2/M input + $8/M output = $10
        #expect(cost == 10)
    }

    @Test func `includes cached input discount in cost`() {
        let record = CodexTokenUsageRecord(
            inputTokens: 1_000_000,
            outputTokens: 0,
            cachedInputTokens: 1_000_000,
            reasoningOutputTokens: 0,
            timestamp: Date()
        )
        let cost = CodexModelPricing.cost(for: record)
        // $2/M input + $0.50/M cached = $2.50
        #expect(cost == Decimal(string: "2.5")!)
    }

    @Test func `returns zero for zero tokens`() {
        let record = CodexTokenUsageRecord(
            inputTokens: 0,
            outputTokens: 0,
            cachedInputTokens: 0,
            reasoningOutputTokens: 0,
            timestamp: Date()
        )
        let cost = CodexModelPricing.cost(for: record)
        #expect(cost == 0)
    }

    @Test func `default price matches GPT-5 pricing`() {
        let defaultPrice = CodexModelPricing.defaultPrice
        let gpt5Price = CodexModelPricing.price(for: "gpt-5")
        #expect(defaultPrice.inputPer1M == gpt5Price.inputPer1M)
        #expect(defaultPrice.outputPer1M == gpt5Price.outputPer1M)
    }

    @Test func `looks up known model prices`() {
        let o4Mini = CodexModelPricing.price(for: "o4-mini")
        #expect(o4Mini.inputPer1M == Decimal(string: "0.4")!)
        #expect(o4Mini.outputPer1M == Decimal(string: "1.6")!)
    }

    @Test func `falls back to default for unknown models`() {
        let unknown = CodexModelPricing.price(for: "unknown-model-xyz")
        #expect(unknown.inputPer1M == CodexModelPricing.defaultPrice.inputPer1M)
    }
}
