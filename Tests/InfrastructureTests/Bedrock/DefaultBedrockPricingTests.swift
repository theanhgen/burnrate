import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("DefaultBedrockPricing Tests")
struct DefaultBedrockPricingTests {

    // MARK: - Exact Match Tests

    @Test
    func `returns pricing for known Claude Opus model`() {
        let model = DefaultBedrockPricing.model(for: "anthropic.claude-opus-4-5-20251101-v1:0")
        #expect(model != nil)
        #expect(model?.displayName == "Claude Opus 4.5")
        #expect(model?.vendor == "Anthropic")
        #expect(model?.inputPricePer1M == 15.00)
        #expect(model?.outputPricePer1M == 75.00)
    }

    @Test
    func `returns pricing for known Claude Sonnet model`() {
        let model = DefaultBedrockPricing.model(for: "anthropic.claude-sonnet-4-20250514-v1:0")
        #expect(model != nil)
        #expect(model?.displayName == "Claude Sonnet 4")
        #expect(model?.inputPricePer1M == 3.00)
        #expect(model?.outputPricePer1M == 15.00)
    }

    @Test
    func `returns pricing for known Claude Haiku model`() {
        let model = DefaultBedrockPricing.model(for: "anthropic.claude-haiku-4-5-20251001-v1:0")
        #expect(model != nil)
        #expect(model?.displayName == "Claude Haiku 4.5")
        #expect(model?.inputPricePer1M == 1.00)
    }

    @Test
    func `returns pricing for Amazon Titan model`() {
        let model = DefaultBedrockPricing.model(for: "amazon.titan-text-premier-v1:0")
        #expect(model != nil)
        #expect(model?.vendor == "Amazon")
        #expect(model?.displayName == "Titan Text Premier")
    }

    @Test
    func `returns pricing for Meta Llama model`() {
        let model = DefaultBedrockPricing.model(for: "meta.llama3-2-90b-instruct-v1:0")
        #expect(model != nil)
        #expect(model?.vendor == "Meta")
    }

    @Test
    func `returns pricing for Mistral model`() {
        let model = DefaultBedrockPricing.model(for: "mistral.mistral-large-2407-v1:0")
        #expect(model != nil)
        #expect(model?.vendor == "Mistral AI")
    }

    // MARK: - Regional Prefix Normalization Tests

    @Test
    func `strips us regional prefix`() {
        let model = DefaultBedrockPricing.model(for: "us.anthropic.claude-sonnet-4-20250514-v1:0")
        #expect(model != nil)
        #expect(model?.displayName == "Claude Sonnet 4")
    }

    @Test
    func `strips eu regional prefix`() {
        let model = DefaultBedrockPricing.model(for: "eu.anthropic.claude-sonnet-4-20250514-v1:0")
        #expect(model != nil)
        #expect(model?.displayName == "Claude Sonnet 4")
    }

    @Test
    func `strips ap regional prefix`() {
        let model = DefaultBedrockPricing.model(for: "ap.anthropic.claude-sonnet-4-20250514-v1:0")
        #expect(model != nil)
    }

    @Test
    func `preserves original model ID with regional prefix`() {
        let model = DefaultBedrockPricing.model(for: "us.anthropic.claude-sonnet-4-20250514-v1:0")
        #expect(model?.id == "us.anthropic.claude-sonnet-4-20250514-v1:0")
    }

    // MARK: - Partial Match Tests (without version suffix)

    @Test
    func `matches without version suffix`() {
        let model = DefaultBedrockPricing.model(for: "amazon.titan-text-express-v1")
        #expect(model != nil)
        #expect(model?.displayName == "Titan Text Express")
    }

    // MARK: - Unknown Model Tests

    @Test
    func `returns nil for unknown model`() {
        let model = DefaultBedrockPricing.model(for: "unknown.model-v1:0")
        #expect(model == nil)
    }

    @Test
    func `returns nil for empty model id`() {
        let model = DefaultBedrockPricing.model(for: "")
        #expect(model == nil)
    }

    // MARK: - All Known Models Coverage

    @Test
    func `all Claude models are present`() {
        let claudeModels = [
            "anthropic.claude-opus-4-5-20251101-v1:0",
            "anthropic.claude-haiku-4-5-20251001-v1:0",
            "anthropic.claude-sonnet-4-20250514-v1:0",
            "anthropic.claude-3-5-sonnet-20241022-v2:0",
            "anthropic.claude-3-5-sonnet-20240620-v1:0",
            "anthropic.claude-3-5-haiku-20241022-v1:0",
            "anthropic.claude-3-opus-20240229-v1:0",
            "anthropic.claude-3-sonnet-20240229-v1:0",
            "anthropic.claude-3-haiku-20240307-v1:0",
        ]

        for modelId in claudeModels {
            let model = DefaultBedrockPricing.model(for: modelId)
            #expect(model != nil, "Missing pricing for \(modelId)")
            #expect(model?.vendor == "Anthropic")
        }
    }
}
