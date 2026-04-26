import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("KiroProvider Tests")
struct KiroProviderTests {

    private func makeSettingsRepository(enabled: Bool = true) -> MockProviderSettingsRepository {
        MockRepositoryFactory.makeSettingsRepository(enabled: enabled)
    }

    // MARK: - Identity Tests

    @Test
    func `kiro provider has correct id`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.id == "kiro")
    }

    @Test
    func `kiro provider has correct name`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.name == "Kiro")
    }

    @Test
    func `kiro provider has correct cliCommand`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.cliCommand == "kiro-cli")
    }

    @Test
    func `kiro provider has dashboard URL`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.dashboardURL == URL(string: "https://app.kiro.dev/account/usage"))
    }

    @Test
    func `kiro provider has no status page URL`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.statusPageURL == nil)
    }

    @Test
    func `kiro provider is enabled by default`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isEnabled == true)
    }

    // MARK: - State Tests

    @Test
    func `kiro provider starts with no snapshot`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.snapshot == nil)
    }

    @Test
    func `kiro provider starts not syncing`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isSyncing == false)
    }

    @Test
    func `kiro provider starts with no error`() {
        let provider = KiroProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test
    func `kiro provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test
    func `kiro provider delegates isAvailable false to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(false)
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == false)
    }

    @Test
    func `kiro provider delegates refresh to probe`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "kiro",
            quotas: [UsageQuota(percentRemaining: 70, quotaType: .session, providerId: "kiro", resetText: "Resets daily")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let snapshot = try await provider.refresh()

        #expect(snapshot.providerId == "kiro")
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 70)
    }

    // MARK: - Snapshot Storage Tests

    @Test
    func `kiro provider stores snapshot after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "kiro",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "kiro")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.snapshot == nil)
        _ = try await provider.refresh()
        #expect(provider.snapshot != nil)
        #expect(provider.snapshot?.quotas.first?.percentRemaining == 50)
    }

    // MARK: - Error Handling Tests

    @Test
    func `kiro provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("CLI not found"))
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.lastError == nil)
        do { _ = try await provider.refresh() } catch {}
        #expect(provider.lastError != nil)
    }

    @Test
    func `kiro provider rethrows probe errors`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        await #expect(throws: ProbeError.timeout) {
            try await provider.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test
    func `kiro provider resets isSyncing after refresh completes`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(providerId: "kiro", quotas: [], capturedAt: Date()))
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        _ = try await provider.refresh()
        #expect(provider.isSyncing == false)
    }

    @Test
    func `kiro provider resets isSyncing after refresh fails`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = KiroProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.isSyncing == false)
    }
}
