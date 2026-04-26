import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("AmpCodeProvider Tests")
struct AmpCodeProviderTests {

    private func makeSettingsRepository(enabled: Bool = true) -> MockProviderSettingsRepository {
        MockRepositoryFactory.makeSettingsRepository(enabled: enabled)
    }

    // MARK: - Identity Tests

    @Test
    func `ampcode provider has correct id`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.id == "ampcode")
    }

    @Test
    func `ampcode provider has correct name`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.name == "Amp")
    }

    @Test
    func `ampcode provider has correct cliCommand`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.cliCommand == "amp")
    }

    @Test
    func `ampcode provider has dashboard URL`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.dashboardURL == URL(string: "https://ampcode.com/settings"))
    }

    @Test
    func `ampcode provider has no status page URL`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.statusPageURL == nil)
    }

    @Test
    func `ampcode provider is enabled by default`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isEnabled == true)
    }

    // MARK: - State Tests

    @Test
    func `ampcode provider starts with no snapshot`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.snapshot == nil)
    }

    @Test
    func `ampcode provider starts not syncing`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isSyncing == false)
    }

    @Test
    func `ampcode provider starts with no error`() {
        let provider = AmpCodeProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test
    func `ampcode provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test
    func `ampcode provider delegates isAvailable false to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(false)
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == false)
    }

    @Test
    func `ampcode provider delegates refresh to probe`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "ampcode",
            quotas: [UsageQuota(percentRemaining: 90, quotaType: .session, providerId: "ampcode", resetText: "Resets in 2 hours")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let snapshot = try await provider.refresh()

        #expect(snapshot.providerId == "ampcode")
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 90)
    }

    // MARK: - Snapshot Storage Tests

    @Test
    func `ampcode provider stores snapshot after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "ampcode",
            quotas: [UsageQuota(percentRemaining: 75, quotaType: .session, providerId: "ampcode")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.snapshot == nil)
        _ = try await provider.refresh()
        #expect(provider.snapshot != nil)
        #expect(provider.snapshot?.quotas.first?.percentRemaining == 75)
    }

    @Test
    func `ampcode provider clears error on successful refresh`() async throws {
        let failingProbe = MockUsageProbe()
        given(failingProbe).probe().willThrow(ProbeError.timeout)
        let settings = makeSettingsRepository()
        let failProvider = AmpCodeProvider(probe: failingProbe, settingsRepository: settings)

        do { _ = try await failProvider.refresh() } catch {}
        #expect(failProvider.lastError != nil)

        let succeedingProbe = MockUsageProbe()
        given(succeedingProbe).probe().willReturn(UsageSnapshot(providerId: "ampcode", quotas: [], capturedAt: Date()))
        let successProvider = AmpCodeProvider(probe: succeedingProbe, settingsRepository: settings)

        _ = try await successProvider.refresh()
        #expect(successProvider.lastError == nil)
    }

    // MARK: - Error Handling Tests

    @Test
    func `ampcode provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("Connection refused"))
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.lastError == nil)
        do { _ = try await provider.refresh() } catch {}
        #expect(provider.lastError != nil)
    }

    @Test
    func `ampcode provider rethrows probe errors`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("Connection refused"))
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        await #expect(throws: ProbeError.executionFailed("Connection refused")) {
            try await provider.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test
    func `ampcode provider resets isSyncing after refresh completes`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(providerId: "ampcode", quotas: [], capturedAt: Date()))
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.isSyncing == false)
        _ = try await provider.refresh()
        #expect(provider.isSyncing == false)
    }

    @Test
    func `ampcode provider resets isSyncing after refresh fails`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = AmpCodeProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.isSyncing == false)
    }
}
