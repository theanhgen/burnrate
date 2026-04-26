import Testing
import Foundation
import Mockable
@testable import Domain
@testable import Infrastructure

@Suite("BedrockProvider Tests")
struct BedrockProviderTests {

    // MARK: - Mock Settings (reuse pattern from BedrockUsageProbeTests)

    final class MockBedrockSettings: BedrockSettingsRepository, @unchecked Sendable {
        var profileName: String = ""
        var regions: [String] = ["us-east-1"]
        var dailyBudget: Decimal? = nil
        var enabledState: Bool = false

        func awsProfileName() -> String { profileName }
        func setAWSProfileName(_ name: String) { profileName = name }
        func bedrockRegions() -> [String] { regions }
        func setBedrockRegions(_ regions: [String]) { self.regions = regions }
        func bedrockDailyBudget() -> Decimal? { dailyBudget }
        func setBedrockDailyBudget(_ amount: Decimal?) { dailyBudget = amount }
        func isEnabled(forProvider id: String, defaultValue: Bool) -> Bool { enabledState }
        func setEnabled(_ enabled: Bool, forProvider id: String) { enabledState = enabled }
        func customCardURL(forProvider id: String) -> String? { nil }
        func setCustomCardURL(_ url: String?, forProvider id: String) {}
    }

    // MARK: - Identity Tests

    @Test
    func `bedrock provider has correct id`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.id == "bedrock")
    }

    @Test
    func `bedrock provider has correct name`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.name == "AWS Bedrock")
    }

    @Test
    func `bedrock provider has correct cliCommand`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.cliCommand == "aws")
    }

    @Test
    func `bedrock provider has dashboard URL`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.dashboardURL == URL(string: "https://console.aws.amazon.com/bedrock/home"))
    }

    @Test
    func `bedrock provider has status page URL`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.statusPageURL == URL(string: "https://health.aws.amazon.com/health/status"))
    }

    @Test
    func `bedrock provider is disabled by default`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.isEnabled == false)
    }

    // MARK: - State Tests

    @Test
    func `bedrock provider starts with no snapshot`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.snapshot == nil)
    }

    @Test
    func `bedrock provider starts not syncing`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.isSyncing == false)
    }

    @Test
    func `bedrock provider starts with no error`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.lastError == nil)
    }

    // MARK: - Delegation Tests

    @Test
    func `bedrock provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test
    func `bedrock provider delegates refresh to probe`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "bedrock",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .budget, providerId: "bedrock")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        let snapshot = try await provider.refresh()
        #expect(snapshot.providerId == "bedrock")
        #expect(snapshot.quotas.count == 1)
    }

    // MARK: - Snapshot Storage Tests

    @Test
    func `bedrock provider stores snapshot after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        let expectedSnapshot = UsageSnapshot(
            providerId: "bedrock",
            quotas: [UsageQuota(percentRemaining: 40, quotaType: .budget, providerId: "bedrock")],
            capturedAt: Date()
        )
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        #expect(provider.snapshot == nil)
        _ = try await provider.refresh()
        #expect(provider.snapshot != nil)
    }

    // MARK: - Error Handling Tests

    @Test
    func `bedrock provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.executionFailed("AWS credentials expired"))
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.lastError != nil)
    }

    @Test
    func `bedrock provider rethrows probe errors`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        await #expect(throws: ProbeError.timeout) {
            try await provider.refresh()
        }
    }

    // MARK: - Syncing State Tests

    @Test
    func `bedrock provider resets isSyncing after refresh`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(providerId: "bedrock", quotas: [], capturedAt: Date()))
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        _ = try await provider.refresh()
        #expect(provider.isSyncing == false)
    }

    @Test
    func `bedrock provider resets isSyncing after refresh fails`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let provider = BedrockProvider(probe: mockProbe, settingsRepository: MockBedrockSettings())

        do { _ = try await provider.refresh() } catch {}
        #expect(provider.isSyncing == false)
    }

    // MARK: - Bedrock-Specific Accessor Tests

    @Test
    func `bedrock provider bedrockUsage is nil when no snapshot`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.bedrockUsage == nil)
    }

    @Test
    func `bedrock provider formattedTodayCost is nil when no snapshot`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.formattedTodayCost == nil)
    }

    @Test
    func `bedrock provider modelsBySpend is empty when no snapshot`() {
        let provider = BedrockProvider(probe: MockUsageProbe(), settingsRepository: MockBedrockSettings())
        #expect(provider.modelsBySpend.isEmpty)
    }
}
