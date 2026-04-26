import Testing
import Foundation
@testable import Domain

@Suite("BedrockModels Tests")
struct BedrockModelsTests {

    // MARK: - Helpers

    private func sampleModel(
        id: String = "anthropic.claude-sonnet-4-20250514-v1:0",
        inputPrice: Decimal = 3,
        outputPrice: Decimal = 15
    ) -> BedrockModel {
        BedrockModel(
            id: id,
            displayName: "Claude Sonnet 4",
            vendor: "Anthropic",
            inputPricePer1M: inputPrice,
            outputPricePer1M: outputPrice
        )
    }

    private func sampleUsage(
        model: BedrockModel? = nil,
        invocations: Int = 100,
        inputTokens: Int = 500_000,
        outputTokens: Int = 200_000
    ) -> BedrockModelUsage {
        BedrockModelUsage(
            model: model ?? sampleModel(),
            invocations: invocations,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    // MARK: - BedrockModel Tests

    @Test
    func `model formatted input price`() {
        let model = sampleModel(inputPrice: 15)
        #expect(model.formattedInputPrice == "$15.00 / 1M")
    }

    @Test
    func `model formatted output price`() {
        let model = sampleModel(outputPrice: 75)
        #expect(model.formattedOutputPrice == "$75.00 / 1M")
    }

    @Test
    func `model zero price formats correctly`() {
        let model = sampleModel(inputPrice: 0, outputPrice: 0)
        #expect(model.formattedInputPrice == "$0.00 / 1M")
        #expect(model.formattedOutputPrice == "$0.00 / 1M")
    }

    // MARK: - BedrockModelUsage Cost Tests

    @Test
    func `usage estimated cost calculation`() {
        let model = sampleModel(inputPrice: 3, outputPrice: 15)
        let usage = BedrockModelUsage(model: model, invocations: 10, inputTokens: 1_000_000, outputTokens: 500_000)

        // Input: 1M * $3/1M = $3.00
        // Output: 0.5M * $15/1M = $7.50
        // Total = $10.50
        #expect(usage.estimatedCost == Decimal(string: "10.5"))
    }

    @Test
    func `usage zero tokens has zero cost`() {
        let usage = BedrockModelUsage(model: sampleModel(), invocations: 0, inputTokens: 0, outputTokens: 0)
        #expect(usage.estimatedCost == 0)
    }

    @Test
    func `usage formatted cost`() {
        let model = sampleModel(inputPrice: 3, outputPrice: 15)
        let usage = BedrockModelUsage(model: model, invocations: 10, inputTokens: 1_000_000, outputTokens: 0)
        #expect(usage.formattedCost == "$3.00")
    }

    // MARK: - Token Formatting Tests

    @Test
    func `format millions of tokens`() {
        let usage = sampleUsage(inputTokens: 1_500_000, outputTokens: 0)
        #expect(usage.formattedInputTokens == "1.5M")
    }

    @Test
    func `format thousands of tokens`() {
        let usage = sampleUsage(inputTokens: 500_000, outputTokens: 0)
        #expect(usage.formattedInputTokens == "500K")
    }

    @Test
    func `format small token counts`() {
        let usage = sampleUsage(inputTokens: 999, outputTokens: 0)
        #expect(usage.formattedInputTokens == "999")
    }

    @Test
    func `formatted total tokens sums input and output`() {
        let usage = sampleUsage(inputTokens: 1_000_000, outputTokens: 500_000)
        #expect(usage.formattedTotalTokens == "1.5M")
    }

    // MARK: - BedrockUsageSummary Tests

    @Test
    func `summary total invocations`() {
        let usage1 = sampleUsage(invocations: 50)
        let usage2 = sampleUsage(invocations: 30)
        let summary = BedrockUsageSummary(
            modelUsages: [usage1, usage2],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        #expect(summary.totalInvocations == 80)
    }

    @Test
    func `summary total input tokens`() {
        let usage1 = sampleUsage(inputTokens: 1_000_000)
        let usage2 = sampleUsage(inputTokens: 500_000)
        let summary = BedrockUsageSummary(
            modelUsages: [usage1, usage2],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        #expect(summary.totalInputTokens == 1_500_000)
    }

    @Test
    func `summary total output tokens`() {
        let usage1 = sampleUsage(outputTokens: 200_000)
        let usage2 = sampleUsage(outputTokens: 300_000)
        let summary = BedrockUsageSummary(
            modelUsages: [usage1, usage2],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        #expect(summary.totalOutputTokens == 500_000)
    }

    @Test
    func `summary total tokens sums input and output`() {
        let usage = sampleUsage(inputTokens: 1_000_000, outputTokens: 500_000)
        let summary = BedrockUsageSummary(
            modelUsages: [usage],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        #expect(summary.totalTokens == 1_500_000)
    }

    @Test
    func `summary total cost`() {
        let model = sampleModel(inputPrice: 3, outputPrice: 15)
        let usage = BedrockModelUsage(model: model, invocations: 10, inputTokens: 1_000_000, outputTokens: 1_000_000)
        let summary = BedrockUsageSummary(
            modelUsages: [usage],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        // Input: 1M * $3 = $3, Output: 1M * $15 = $15 => Total: $18
        #expect(summary.totalCost == 18)
    }

    @Test
    func `summary formatted total cost`() {
        let model = sampleModel(inputPrice: 0, outputPrice: 0)
        let usage = BedrockModelUsage(model: model, invocations: 0, inputTokens: 0, outputTokens: 0)
        let summary = BedrockUsageSummary(
            modelUsages: [usage],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        #expect(summary.formattedTotalCost == "$0.00")
    }

    // MARK: - Budget Tests

    @Test
    func `summary budget percent used`() {
        let model = sampleModel(inputPrice: 10, outputPrice: 0)
        let usage = BedrockModelUsage(model: model, invocations: 1, inputTokens: 1_000_000, outputTokens: 0)
        // Cost = $10
        let summary = BedrockUsageSummary(
            modelUsages: [usage],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date(),
            dailyBudget: 50
        )
        // 10/50 * 100 = 20%
        #expect(summary.budgetPercentUsed == 20.0)
    }

    @Test
    func `summary budget percent nil when no budget`() {
        let summary = BedrockUsageSummary(
            modelUsages: [],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date(),
            dailyBudget: nil
        )
        #expect(summary.budgetPercentUsed == nil)
    }

    @Test
    func `summary budget status within budget`() {
        let summary = BedrockUsageSummary(
            modelUsages: [],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date(),
            dailyBudget: 100
        )
        #expect(summary.budgetStatus == .withinBudget)
    }

    @Test
    func `summary budget status nil when no budget`() {
        let summary = BedrockUsageSummary(
            modelUsages: [],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date(),
            dailyBudget: nil
        )
        #expect(summary.budgetStatus == nil)
    }

    @Test
    func `summary formatted daily budget`() {
        let summary = BedrockUsageSummary(
            modelUsages: [],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date(),
            dailyBudget: 50
        )
        #expect(summary.formattedDailyBudget == "$50.00")
    }

    @Test
    func `summary formatted daily budget nil when no budget`() {
        let summary = BedrockUsageSummary(
            modelUsages: [],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date(),
            dailyBudget: nil
        )
        #expect(summary.formattedDailyBudget == nil)
    }

    // MARK: - Model Queries Tests

    @Test
    func `summary usage for specific model`() {
        let model1 = sampleModel(id: "model-a")
        let model2 = sampleModel(id: "model-b")
        let usage1 = BedrockModelUsage(model: model1, invocations: 10, inputTokens: 100, outputTokens: 50)
        let usage2 = BedrockModelUsage(model: model2, invocations: 20, inputTokens: 200, outputTokens: 100)
        let summary = BedrockUsageSummary(
            modelUsages: [usage1, usage2],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )

        let found = summary.usage(for: "model-a")
        #expect(found?.invocations == 10)
    }

    @Test
    func `summary usage for unknown model returns nil`() {
        let summary = BedrockUsageSummary(
            modelUsages: [],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )
        #expect(summary.usage(for: "nonexistent") == nil)
    }

    @Test
    func `summary models by spend sorted descending`() {
        let cheap = BedrockModelUsage(model: sampleModel(inputPrice: 1, outputPrice: 1), invocations: 1, inputTokens: 1_000_000, outputTokens: 0)
        let expensive = BedrockModelUsage(model: sampleModel(id: "exp", inputPrice: 100, outputPrice: 100), invocations: 1, inputTokens: 1_000_000, outputTokens: 0)
        let summary = BedrockUsageSummary(
            modelUsages: [cheap, expensive],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )

        let sorted = summary.modelsBySpend
        #expect(sorted.first?.estimatedCost ?? 0 > sorted.last?.estimatedCost ?? 0)
    }

    @Test
    func `summary models by invocations sorted descending`() {
        let low = sampleUsage(invocations: 5)
        let high = sampleUsage(invocations: 100)
        let summary = BedrockUsageSummary(
            modelUsages: [low, high],
            region: "us-east-1",
            periodStart: Date(),
            periodEnd: Date()
        )

        let sorted = summary.modelsByInvocations
        #expect(sorted.first?.invocations == 100)
    }

    // MARK: - Empty Summary Tests

    @Test
    func `empty summary has no model usages`() {
        let summary = BedrockUsageSummary.empty(region: "us-west-2")
        #expect(summary.modelUsages.isEmpty)
        #expect(summary.region == "us-west-2")
        #expect(summary.totalCost == 0)
    }
}
