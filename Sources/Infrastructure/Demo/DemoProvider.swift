import Foundation
import Domain

#if DEBUG
/// A specialized provider for generating realistic App Store screenshots.
public final class DemoProvider: AIProvider, @unchecked Sendable {
    public let id: String
    public let name: String
    public let cliCommand: String = ""
    public let dashboardURL: URL? = nil
    public var isEnabled: Bool = true
    public var isSyncing: Bool = false
    public var lastError: Error? = nil
    public var snapshot: UsageSnapshot?

    private let demoQuotas: [UsageQuota]

    public init(id: String, name: String, iconName: String, quotas: [UsageQuota]) {
        self.id = id
        self.name = name
        self.demoQuotas = quotas
        self.snapshot = UsageSnapshot(providerId: id, quotas: quotas, capturedAt: Date())
    }

    public func isAvailable() async -> Bool { true }

    public func refresh() async throws -> UsageSnapshot {
        isSyncing = true
        try? await Task.sleep(for: .milliseconds(500))
        isSyncing = false
        return snapshot!
    }

    /// Factory for a perfect "Hero" set
    public static func createHeroSet() -> [DemoProvider] {
        [
            DemoProvider(
                id: "claude",
                name: "Claude",
                iconName: "antenna.radiowaves.left.and.right",
                quotas: [
                    UsageQuota(percentRemaining: 85, quotaType: .session, providerId: "claude"),
                    UsageQuota(percentRemaining: 42, quotaType: .weekly, providerId: "claude")
                ]
            ),
            DemoProvider(
                id: "gemini",
                name: "Gemini",
                iconName: "sparkles",
                quotas: [
                    UsageQuota(percentRemaining: 15, quotaType: .modelSpecific( "Ultra"), providerId: "gemini"),
                    UsageQuota(percentRemaining: 68, quotaType: .modelSpecific( "Flash"), providerId: "gemini")
                ]
            ),
            DemoProvider(
                id: "copilot",
                name: "GitHub Copilot",
                iconName: "cpu",
                quotas: [
                    UsageQuota(percentRemaining: 92, quotaType: .session, providerId: "copilot")
                ]
            ),
            DemoProvider(
                id: "bedrock",
                name: "AWS Bedrock",
                iconName: "cloud",
                quotas: [
                    UsageQuota(percentRemaining: 5, quotaType: .session, providerId: "bedrock")
                ]
            )
        ]
    }
}
#endif
