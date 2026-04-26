import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("MiniMaxProvider Tests")
struct MiniMaxProviderTests {

    // MARK: - Mock Settings

    final class MockMiniMaxSettings: MiniMaxSettingsRepository, @unchecked Sendable {
        var enabledState: Bool = false
        var region: MiniMaxRegion = .china
        var authEnvVar: String = ""
        var apiKey: String? = nil

        func minimaxRegion() -> MiniMaxRegion { region }
        func setMinimaxRegion(_ region: MiniMaxRegion) { self.region = region }
        func minimaxAuthEnvVar() -> String { authEnvVar }
        func setMinimaxAuthEnvVar(_ envVar: String) { authEnvVar = envVar }
        func saveMinimaxApiKey(_ key: String) { apiKey = key }
        func getMinimaxApiKey() -> String? { apiKey }
        func deleteMinimaxApiKey() { apiKey = nil }
        func hasMinimaxApiKey() -> Bool { apiKey != nil }
        func isEnabled(forProvider id: String, defaultValue: Bool) -> Bool { enabledState }
        func setEnabled(_ enabled: Bool, forProvider id: String) { enabledState = enabled }
        func customCardURL(forProvider id: String) -> String? { nil }
        func setCustomCardURL(_ url: String?, forProvider id: String) {}
    }

    // MARK: - Identity Tests

    @Test
    func `minimax provider has correct id`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.id == "minimax")
    }

    @Test
    func `minimax provider has correct name`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.name == "MiniMax")
    }

    @Test
    func `minimax provider has empty cliCommand`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.cliCommand == "")
    }

    @Test
    func `minimax provider dashboardURL reflects region`() {
        let settings = MockMiniMaxSettings()
        settings.region = .china
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: settings)
        #expect(provider.dashboardURL == MiniMaxRegion.china.dashboardURL)
    }

    @Test
    func `minimax provider dashboardURL changes with international region`() {
        let settings = MockMiniMaxSettings()
        settings.region = .international
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: settings)
        #expect(provider.dashboardURL == MiniMaxRegion.international.dashboardURL)
    }

    @Test
    func `minimax provider has no status page URL`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.statusPageURL == nil)
    }

    @Test
    func `minimax provider is disabled by default`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.isEnabled == false)
    }

    // MARK: - State Tests

    @Test
    func `minimax provider starts with no snapshot`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.snapshot == nil)
    }

    @Test
    func `minimax provider starts not syncing`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.isSyncing == false)
    }

    @Test
    func `minimax provider starts with no error`() {
        let provider = MiniMaxProvider(probe: MockUsageProbe(), settingsRepository: MockMiniMaxSettings())
        #expect(provider.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test
    func `minimax provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test
    func `minimax provider delegates refresh to probe`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "minimax",
            quotas: [UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "minimax")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        let snapshot = try await provider.refresh()
        #expect(snapshot.providerId == "minimax")
        #expect(snapshot.quotas.first?.percentRemaining == 80)
    }

    // MARK: - Snapshot Storage Tests

    @Test
    func `minimax provider stores snapshot after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "minimax",
            quotas: [UsageQuota(percentRemaining: 30, quotaType: .session, providerId: "minimax")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        #expect(provider.snapshot == nil)
        _ = try await provider.refresh()
        #expect(provider.snapshot != nil)
    }

    // MARK: - Error Handling Tests

    @Test
    func `minimax provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("API key invalid"))
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.lastError != nil)
    }

    @Test
    func `minimax provider rethrows probe errors`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        await #expect(throws: ProbeError.timeout) {
            try await provider.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test
    func `minimax provider resets isSyncing after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(providerId: "minimax", quotas: [], capturedAt: Date()))
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        _ = try await provider.refresh()
        #expect(provider.isSyncing == false)
    }

    @Test
    func `minimax provider resets isSyncing after refresh fails`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = MiniMaxProvider(probe: mockProbe, settingsRepository: MockMiniMaxSettings())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.isSyncing == false)
    }
}
