import Foundation
import Observation

/// Codex AI provider - a rich domain model.
/// Observable class with its own state (isSyncing, snapshot, error).
/// Supports dual probe modes: RPC (default) and API.
@Observable
public final class CodexProvider: AIProvider, @unchecked Sendable {
    // MARK: - Identity

    public let id: String = "codex"
    public let name: String = "Codex"
    public let cliCommand: String = "codex"

    public var dashboardURL: URL? {
        URL(string: "https://platform.openai.com/usage")
    }

    public var statusPageURL: URL? {
        URL(string: "https://status.openai.com")
    }

    /// Whether the provider is enabled (persisted via settingsRepository)
    public var isEnabled: Bool {
        didSet {
            settingsRepository.setEnabled(isEnabled, forProvider: id)
        }
    }

    // MARK: - State (Observable)

    public private(set) var isSyncing: Bool = false
    public private(set) var snapshot: UsageSnapshot?
    public private(set) var lastError: Error?

    // MARK: - Probe Mode

    /// The current probe mode (RPC or API)
    public var probeMode: CodexProbeMode {
        get {
            if let codexSettings = settingsRepository as? CodexSettingsRepository {
                return codexSettings.codexProbeMode()
            }
            return .rpc
        }
        set {
            if let codexSettings = settingsRepository as? CodexSettingsRepository {
                codexSettings.setCodexProbeMode(newValue)
            }
        }
    }

    // MARK: - Internal

    /// The RPC probe for fetching usage data via `codex app-server`
    private let rpcProbe: any UsageProbe

    /// The API probe for fetching usage data via HTTP API (optional)
    private let apiProbe: (any UsageProbe)?

    /// The settings repository for persisting provider settings
    private let settingsRepository: any ProviderSettingsRepository

    /// Optional daily usage analyzer for token-level tracking from session logs
    private let dailyUsageAnalyzer: (any DailyUsageAnalyzing)?

    /// Returns the active probe based on current mode
    private var activeProbe: any UsageProbe {
        switch probeMode {
        case .rpc:
            return rpcProbe
        case .api:
            // Fall back to RPC if API probe not available
            return apiProbe ?? rpcProbe
        }
    }

    // MARK: - Initialization

    /// Creates a Codex provider with RPC probe only (legacy initializer)
    /// - Parameters:
    ///   - probe: The RPC probe to use for fetching usage data
    ///   - settingsRepository: The repository for persisting settings
    ///   - dailyUsageAnalyzer: Optional analyzer for token-level daily usage from session logs
    public init(
        probe: any UsageProbe,
        settingsRepository: any ProviderSettingsRepository,
        dailyUsageAnalyzer: (any DailyUsageAnalyzing)? = nil
    ) {
        self.rpcProbe = probe
        self.apiProbe = nil
        self.settingsRepository = settingsRepository
        self.dailyUsageAnalyzer = dailyUsageAnalyzer
        self.isEnabled = settingsRepository.isEnabled(forProvider: "codex")
    }

    /// Creates a Codex provider with both RPC and API probes
    /// - Parameters:
    ///   - rpcProbe: The RPC probe for fetching usage via `codex app-server`
    ///   - apiProbe: The API probe for fetching usage via HTTP API
    ///   - settingsRepository: The repository for persisting settings (must be CodexSettingsRepository for mode switching)
    ///   - dailyUsageAnalyzer: Optional analyzer for token-level daily usage from session logs
    public init(
        rpcProbe: any UsageProbe,
        apiProbe: any UsageProbe,
        settingsRepository: any CodexSettingsRepository,
        dailyUsageAnalyzer: (any DailyUsageAnalyzing)? = nil
    ) {
        self.rpcProbe = rpcProbe
        self.apiProbe = apiProbe
        self.settingsRepository = settingsRepository
        self.dailyUsageAnalyzer = dailyUsageAnalyzer
        self.isEnabled = settingsRepository.isEnabled(forProvider: "codex")
    }

    // MARK: - AIProvider Protocol

    public func isAvailable() async -> Bool {
        await activeProbe.isAvailable()
    }

    @discardableResult
    public func refresh() async throws -> UsageSnapshot {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let newSnapshot = try await activeProbe.probe()
            snapshot = await attachDailyReport(to: newSnapshot)
            lastError = nil
            return snapshot!
        } catch {
            // When RPC mode fails and an API probe is available, fall back automatically.
            // The API probe hits chatgpt.com/backend-api directly without the codex CLI.
            if probeMode == .rpc, let api = apiProbe {
                do {
                    let fallbackSnapshot = try await api.probe()
                    snapshot = await attachDailyReport(to: fallbackSnapshot)
                    lastError = nil
                    return snapshot!
                } catch let apiError {
                    lastError = apiError
                    throw apiError
                }
            }
            lastError = error
            throw error
        }
    }

    /// Whether API mode is available (API probe was provided)
    public var supportsApiMode: Bool {
        apiProbe != nil
    }

    // MARK: - Daily Usage

    /// Attaches daily usage report to snapshot if analyzer is available.
    private func attachDailyReport(to snapshot: UsageSnapshot) async -> UsageSnapshot {
        guard let analyzer = dailyUsageAnalyzer,
              let report = try? await analyzer.analyzeToday(),
              !report.today.isEmpty || !report.previous.isEmpty else {
            return snapshot
        }
        return UsageSnapshot(
            providerId: snapshot.providerId,
            quotas: snapshot.quotas,
            capturedAt: snapshot.capturedAt,
            accountEmail: snapshot.accountEmail,
            accountOrganization: snapshot.accountOrganization,
            loginMethod: snapshot.loginMethod,
            accountTier: snapshot.accountTier,
            costUsage: snapshot.costUsage,
            bedrockUsage: snapshot.bedrockUsage,
            dailyUsageReport: report,
            extensionMetrics: snapshot.extensionMetrics
        )
    }
}
