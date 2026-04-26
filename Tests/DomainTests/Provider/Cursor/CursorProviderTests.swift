import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("CursorProvider Tests")
struct CursorProviderTests {

    private func makeSettingsRepository(enabled: Bool = true) -> MockProviderSettingsRepository {
        MockRepositoryFactory.makeSettingsRepository(enabled: enabled)
    }

    // MARK: - Identity Tests

    @Test
    func `cursor provider has correct id`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.id == "cursor")
    }

    @Test
    func `cursor provider has correct name`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.name == "Cursor")
    }

    @Test
    func `cursor provider has correct cliCommand`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.cliCommand == "cursor")
    }

    @Test
    func `cursor provider has dashboard URL`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.dashboardURL == URL(string: "https://www.cursor.com/settings"))
    }

    @Test
    func `cursor provider has no status page URL`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.statusPageURL == nil)
    }

    @Test
    func `cursor provider is enabled by default`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isEnabled == true)
    }

    // MARK: - State Tests

    @Test
    func `cursor provider starts with no snapshot`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.snapshot == nil)
    }

    @Test
    func `cursor provider starts not syncing`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.isSyncing == false)
    }

    @Test
    func `cursor provider starts with no error`() {
        let provider = CursorProvider(probe: MockUsageProbe(), settingsRepository: makeSettingsRepository())
        #expect(provider.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test
    func `cursor provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test
    func `cursor provider delegates isAvailable false to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(false)
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let available = await provider.isAvailable()
        #expect(available == false)
    }

    @Test
    func `cursor provider delegates refresh to probe`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "cursor",
            quotas: [UsageQuota(percentRemaining: 85, quotaType: .session, providerId: "cursor", resetText: "Resets monthly")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        let snapshot = try await provider.refresh()

        #expect(snapshot.providerId == "cursor")
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 85)
    }

    // MARK: - Snapshot Storage Tests

    @Test
    func `cursor provider stores snapshot after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "cursor",
            quotas: [UsageQuota(percentRemaining: 60, quotaType: .session, providerId: "cursor")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.snapshot == nil)
        _ = try await provider.refresh()
        #expect(provider.snapshot != nil)
        #expect(provider.snapshot?.quotas.first?.percentRemaining == 60)
    }

    // MARK: - Error Handling Tests

    @Test
    func `cursor provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("API error"))
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        #expect(provider.lastError == nil)
        do { _ = try await provider.refresh() } catch {}
        #expect(provider.lastError != nil)
    }

    @Test
    func `cursor provider rethrows probe errors`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        await #expect(throws: ProbeError.timeout) {
            try await provider.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test
    func `cursor provider resets isSyncing after refresh completes`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(providerId: "cursor", quotas: [], capturedAt: Date()))
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        _ = try await provider.refresh()
        #expect(provider.isSyncing == false)
    }

    @Test
    func `cursor provider resets isSyncing after refresh fails`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = CursorProvider(probe: mockProbe, settingsRepository: makeSettingsRepository())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.isSyncing == false)
    }
}
