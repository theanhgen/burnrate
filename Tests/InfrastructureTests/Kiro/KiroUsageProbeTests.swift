import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite("KiroUsageProbe Behavior Tests")
struct KiroUsageProbeTests {

    static let sampleOutput = """
    Estimated Usage | resets on 03/01 | KIRO FREE

    🎁 Bonus credits: 122.54/500 credits used, expires in 29 days

    Credits (0.00 of 50 covered in plan)
    ████████████████████████████████████████████████████████████████████████████████ 0%
    """

    // MARK: - isAvailable Tests

    @Test
    func `isAvailable returns true when kiro-cli binary found`() async {
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).locate(.value("kiro-cli")).willReturn("/usr/local/bin/kiro-cli")

        let probe = KiroUsageProbe(cliExecutor: mockExecutor)

        #expect(await probe.isAvailable() == true)
    }

    @Test
    func `isAvailable returns false when kiro-cli binary not found`() async {
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).locate(.value("kiro-cli")).willReturn(nil)

        let probe = KiroUsageProbe(cliExecutor: mockExecutor)

        #expect(await probe.isAvailable() == false)
    }

    // MARK: - Probe Tests

    @Test
    func `probe returns snapshot on success`() async throws {
        let mockExecutor = MockCLIExecutor()

        given(mockExecutor).locate(.value("kiro-cli")).willReturn("/usr/local/bin/kiro-cli")

        given(mockExecutor)
            .execute(
                binary: .value("kiro-cli"),
                args: .any,
                input: .any,
                timeout: .any,
                workingDirectory: .any,
                autoResponses: .any
            )
            .willReturn(CLIResult(output: Self.sampleOutput, exitCode: 0))

        let probe = KiroUsageProbe(cliExecutor: mockExecutor)

        let snapshot = try await probe.probe()

        #expect(snapshot.providerId == "kiro")
        #expect(snapshot.quotas.count == 2)
    }

    @Test
    func `probe throws cliNotFound when binary not found`() async {
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).locate(.value("kiro-cli")).willReturn(nil)

        let probe = KiroUsageProbe(cliExecutor: mockExecutor)

        await #expect(throws: ProbeError.cliNotFound("kiro-cli")) {
            try await probe.probe()
        }
    }

    @Test
    func `probe throws executionFailed when CLI fails`() async {
        let mockExecutor = MockCLIExecutor()

        given(mockExecutor).locate(.value("kiro-cli")).willReturn("/usr/local/bin/kiro-cli")

        given(mockExecutor)
            .execute(
                binary: .value("kiro-cli"),
                args: .any,
                input: .any,
                timeout: .any,
                workingDirectory: .any,
                autoResponses: .any
            )
            .willThrow(ProbeError.executionFailed("CLI crashed"))

        let probe = KiroUsageProbe(cliExecutor: mockExecutor)

        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    @Test
    func `probe throws parseFailed when output has no quota data`() async {
        let mockExecutor = MockCLIExecutor()

        given(mockExecutor).locate(.value("kiro-cli")).willReturn("/usr/local/bin/kiro-cli")

        given(mockExecutor)
            .execute(
                binary: .value("kiro-cli"),
                args: .any,
                input: .any,
                timeout: .any,
                workingDirectory: .any,
                autoResponses: .any
            )
            .willReturn(CLIResult(output: "Some irrelevant output", exitCode: 0))

        let probe = KiroUsageProbe(cliExecutor: mockExecutor)

        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    @Test
    func `probe uses custom binary name`() async {
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).locate(.value("custom-kiro")).willReturn(nil)

        let probe = KiroUsageProbe(kiroBinary: "custom-kiro", cliExecutor: mockExecutor)

        #expect(await probe.isAvailable() == false)
    }
}
