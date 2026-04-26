import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("MistralProvider Tests")
struct MistralProviderTests {

    private func makeSettingsRepository(enabled: Bool = false) -> MockProviderSettingsRepository {
        MockRepositoryFactory.makeSettingsRepository(enabled: enabled)
    }

    // MARK: - Identity Tests

    @Test
    func `mistral provider has correct id`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.id == "mistral")
    }

    @Test
    func `mistral provider has correct name`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.name == "Mistral")
    }

    @Test
    func `mistral provider has empty cliCommand`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.cliCommand == "")
    }

    @Test
    func `mistral provider has dashboard URL`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.dashboardURL == URL(string: "https://console.mistral.ai"))
    }

    @Test
    func `mistral provider has no status page URL`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.statusPageURL == nil)
    }

    @Test
    func `mistral provider is disabled by default`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isEnabled == false)
    }

    // MARK: - State Tests

    @Test
    func `mistral provider starts with no snapshot`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.snapshot == nil)
    }

    @Test
    func `mistral provider starts not syncing`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isSyncing == false)
    }

    @Test
    func `mistral provider starts with no error`() {
        let provider = MistralProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test
    func `mistral provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let provider = MistralProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test
    func `mistral provider delegates refresh to probe`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "mistral",
            quotas: [UsageQuota(percentRemaining: 100, quotaType: .session, providerId: "mistral")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = MistralProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let snapshot = try await provider.refresh()
        #expect(snapshot.providerId == "mistral")
        #expect(snapshot.quotas.first?.percentRemaining == 100)
    }

    // MARK: - Error Handling Tests

    @Test
    func `mistral provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("API key missing"))
        let provider = MistralProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.lastError != nil)
    }

    @Test
    func `mistral provider rethrows probe errors`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = MistralProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        await #expect(throws: ProbeError.timeout) {
            try await provider.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test
    func `mistral provider resets isSyncing after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(providerId: "mistral", quotas: [], capturedAt: Date()))
        let provider = MistralProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        _ = try await provider.refresh()
        #expect(provider.isSyncing == false)
    }

    @Test
    func `mistral provider resets isSyncing after refresh fails`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = MistralProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.isSyncing == false)
    }
}
