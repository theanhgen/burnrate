import Testing
import Foundation
@testable import Domain

@Suite("ClaudeProbeMode Tests")
struct ClaudeProbeModeTests {

    @Test
    func `cli raw value`() {
        #expect(ClaudeProbeMode.cli.rawValue == "cli")
    }

    @Test
    func `api raw value`() {
        #expect(ClaudeProbeMode.api.rawValue == "api")
    }

    @Test
    func `cli display name`() {
        #expect(ClaudeProbeMode.cli.displayName == "CLI")
    }

    @Test
    func `api display name`() {
        #expect(ClaudeProbeMode.api.displayName == "API")
    }

    @Test
    func `cli description`() {
        #expect(ClaudeProbeMode.cli.description == "Uses claude /usage command")
    }

    @Test
    func `api description`() {
        #expect(ClaudeProbeMode.api.description == "Calls Anthropic API directly")
    }

    @Test
    func `all cases has two modes`() {
        #expect(ClaudeProbeMode.allCases.count == 2)
    }
}

@Suite("CodexProbeMode Tests")
struct CodexProbeModeTests {

    @Test
    func `rpc raw value`() {
        #expect(CodexProbeMode.rpc.rawValue == "rpc")
    }

    @Test
    func `api raw value`() {
        #expect(CodexProbeMode.api.rawValue == "api")
    }

    @Test
    func `rpc display name`() {
        #expect(CodexProbeMode.rpc.displayName == "RPC")
    }

    @Test
    func `api display name`() {
        #expect(CodexProbeMode.api.displayName == "API")
    }

    @Test
    func `rpc description`() {
        #expect(CodexProbeMode.rpc.description == "Uses codex app-server RPC")
    }

    @Test
    func `api description`() {
        #expect(CodexProbeMode.api.description == "Calls ChatGPT API directly")
    }

    @Test
    func `all cases has two modes`() {
        #expect(CodexProbeMode.allCases.count == 2)
    }
}

@Suite("CopilotProbeMode Tests")
struct CopilotProbeModeTests {

    @Test
    func `billing raw value`() {
        #expect(CopilotProbeMode.billing.rawValue == "billing")
    }

    @Test
    func `copilotAPI raw value`() {
        #expect(CopilotProbeMode.copilotAPI.rawValue == "copilotAPI")
    }

    @Test
    func `billing display name`() {
        #expect(CopilotProbeMode.billing.displayName == "Billing")
    }

    @Test
    func `copilotAPI display name`() {
        #expect(CopilotProbeMode.copilotAPI.displayName == "Copilot API")
    }

    @Test
    func `billing description`() {
        #expect(CopilotProbeMode.billing.description == "Uses GitHub Billing API")
    }

    @Test
    func `copilotAPI description`() {
        #expect(CopilotProbeMode.copilotAPI.description == "Uses Copilot Internal API")
    }

    @Test
    func `all cases has two modes`() {
        #expect(CopilotProbeMode.allCases.count == 2)
    }
}

@Suite("KimiProbeMode Tests")
struct KimiProbeModeTests {

    @Test
    func `cli raw value`() {
        #expect(KimiProbeMode.cli.rawValue == "cli")
    }

    @Test
    func `api raw value`() {
        #expect(KimiProbeMode.api.rawValue == "api")
    }

    @Test
    func `cli display name`() {
        #expect(KimiProbeMode.cli.displayName == "CLI")
    }

    @Test
    func `api display name`() {
        #expect(KimiProbeMode.api.displayName == "API")
    }

    @Test
    func `cli description`() {
        #expect(KimiProbeMode.cli.description == "Uses kimi /usage command")
    }

    @Test
    func `api description`() {
        #expect(KimiProbeMode.api.description == "Calls Kimi API directly")
    }

    @Test
    func `all cases has two modes`() {
        #expect(KimiProbeMode.allCases.count == 2)
    }
}
