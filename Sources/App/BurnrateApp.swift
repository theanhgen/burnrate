import SwiftUI
import Domain
import Infrastructure
import CloudSync
import WidgetData
import WidgetKit
#if ENABLE_SPARKLE
import Sparkle
#endif

extension Notification.Name {
    static let hookSettingsChanged = Notification.Name("com.nguyentheanh.burnrate.hookSettingsChanged")
}

@main
struct BurnrateApp: App {
    #if MAS_BUILD
    @NSApplicationDelegateAdaptor(MASLaunchDelegate.self) private var masDelegate
    #endif

    /// The main domain service - monitors all AI providers
    /// This is the single source of truth for providers and their state
    @State private var monitor: QuotaMonitor

    /// Monitors Claude Code sessions via hook events
    @State private var sessionMonitor = SessionMonitor()

    #if !MAS_BUILD
    /// The hook HTTP server that receives events from Claude Code
    private let hookServer = HookHTTPServer()

    /// Task for the hook server event loop (allows cancellation on toggle off)
    @State private var hookServerTask: Task<Void, Never>?

    /// File-based session scanner (terminal-agnostic, always active)
    private let sessionScanner = SessionFileScanner()

    /// Task for the session scanner event loop
    @State private var sessionScannerTask: Task<Void, Never>?

    /// Sends session start/end notifications
    private let sessionAlertSender = SystemAlertSender()
    #endif

    /// Alerts users when quota status degrades
    private let quotaAlerter = NotificationAlerter(settingsRepository: JSONSettingsRepository.shared)

    #if ENABLE_CLOUDSYNC
    /// Pushes usage snapshots to CloudKit for iOS companion app
    private let cloudSyncWriter = CloudKitSnapshotWriter()
    #endif

    #if ENABLE_SPARKLE
    /// Sparkle updater for auto-updates
    @State private var sparkleUpdater = SparkleUpdater()
    #endif

    init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        AppLog.ui.info("burnrate v\(version) (\(build)) initializing...")

        // Create the shared settings repository (JSON-backed: ~/.burnrate/settings.json)
        let settingsRepository = JSONSettingsRepository.shared

        let repository: AIProviders

        #if DEBUG
        let isDemo = ProcessInfo.processInfo.environment["BURNRATE_DEMO"] == "1"
        #else
        let isDemo = false
        #endif

        if isDemo {
            #if DEBUG
            repository = AIProviders(providers: DemoProvider.createHeroSet())
            #else
            repository = AIProviders(providers: [])
            #endif
        } else {
            #if MAS_BUILD
            // MAS build: API-only probes with security-scoped bookmark access
            let bookmarkManager = SecurityScopedBookmarkManager()

            repository = AIProviders(providers: [
                ClaudeProvider(
                    probe: ClaudeAPIUsageProbe(
                        credentialLoader: ClaudeCredentialLoader(bookmarkManager: bookmarkManager)
                    ),
                    settingsRepository: settingsRepository,
                    dailyUsageAnalyzer: ClaudeDailyUsageAnalyzer()
                ),
                CodexProvider(
                    probe: CodexAPIUsageProbe(
                        credentialLoader: CodexCredentialLoader(bookmarkManager: bookmarkManager)
                    ),
                    settingsRepository: settingsRepository,
                    dailyUsageAnalyzer: CodexDailyUsageAnalyzer()
                ),
                GeminiProvider(
                    probe: GeminiUsageProbe(bookmarkManager: bookmarkManager),
                    settingsRepository: settingsRepository
                ),
                CopilotProvider(
                    billingProbe: CopilotUsageProbe(settingsRepository: settingsRepository),
                    internalProbe: CopilotInternalAPIProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                BedrockProvider(
                    probe: BedrockUsageProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                MiniMaxProvider(
                    probe: MiniMaxUsageProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                AlibabaProvider(
                    probe: AlibabaUsageProbe(settingsRepository: settingsRepository, cookieProvider: NoOpCookieProvider()),
                    settingsRepository: settingsRepository
                ),
            ])
            #else
            // Non-MAS build: Full provider list with CLI + API probes
            repository = AIProviders(providers: [
                ClaudeProvider(
                    cliProbe: ClaudeUsageProbe(),
                    apiProbe: ClaudeAPIUsageProbe(),
                    passProbe: ClaudePassProbe(),
                    settingsRepository: settingsRepository,
                    dailyUsageAnalyzer: ClaudeDailyUsageAnalyzer()
                ),
                CodexProvider(
                    rpcProbe: CodexUsageProbe(),
                    apiProbe: CodexAPIUsageProbe(),
                    settingsRepository: settingsRepository,
                    dailyUsageAnalyzer: CodexDailyUsageAnalyzer()
                ),
                GeminiProvider(probe: GeminiUsageProbe(), settingsRepository: settingsRepository),
                AntigravityProvider(probe: AntigravityUsageProbe(), settingsRepository: settingsRepository),
                ZaiProvider(
                    probe: ZaiUsageProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                CopilotProvider(
                    billingProbe: CopilotUsageProbe(settingsRepository: settingsRepository),
                    internalProbe: CopilotInternalAPIProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                BedrockProvider(
                    probe: BedrockUsageProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                AmpCodeProvider(probe: AmpCodeUsageProbe(), settingsRepository: settingsRepository),
                KimiProvider(
                    cliProbe: KimiCLIUsageProbe(),
                    apiProbe: KimiUsageProbe(),
                    settingsRepository: settingsRepository
                ),
                KiroProvider(probe: KiroUsageProbe(), settingsRepository: settingsRepository),
                CursorProvider(probe: CursorUsageProbe(), settingsRepository: settingsRepository),
                MiniMaxProvider(
                    probe: MiniMaxUsageProbe(settingsRepository: settingsRepository),
                    settingsRepository: settingsRepository
                ),
                AlibabaProvider(
                    probe: AlibabaUsageProbe(settingsRepository: settingsRepository, cookieProvider: AlibabaBrowserCookieProvider()),
                    settingsRepository: settingsRepository
                ),
                MistralProvider(
                    probe: MistralUsageProbe(),
                    settingsRepository: settingsRepository
                ),
            ])
            #endif
        }
        AppLog.providers.info("Created \(repository.all.count) providers")

        // Initialize the domain service with quota alerter
        monitor = QuotaMonitor(
            providers: repository,
            alerter: quotaAlerter
        )
        AppLog.monitor.info("QuotaMonitor initialized")

        #if !MAS_BUILD
        // Load user extensions from ~/.burnrate/extensions/
        let extensionRegistry = ExtensionRegistry(
            settingsRepository: settingsRepository,
            configRepository: AppSettings.shared.extensionConfig
        )
        let extensionProviders = extensionRegistry.loadExtensions(into: monitor)
        if !extensionProviders.isEmpty {
            AppLog.providers.info("Loaded \(extensionProviders.count) extension provider(s): \(extensionProviders.map(\.name).joined(separator: ", "))")
        }

        // Inject MCP query handler so API endpoints serve live quota data
        hookServer.queryHandler = QuotaQueryHandlerImpl(monitor: monitor)

        // Always start session file scanner (terminal-agnostic session detection)
        startSessionScanner()

        // Always start the HTTP server (serves MCP API endpoints).
        // Hook installation only happens when hooks are explicitly enabled.
        startHookServer(installHooks: settingsRepository.isHookEnabled())
        #endif

        AppLog.ui.info("burnrate initialization complete")
    }

    /// App settings for theme
    @State private var settings = AppSettings.shared

    /// Status of selected provider, considering burn rate setting
    private var effectiveSelectedProviderStatus: QuotaStatus {
        guard let snapshot = monitor.selectedProvider?.snapshot else { return .healthy }
        if settings.burnrateWarningEnabled {
            return snapshot.paceAwareOverallStatus(burnrateThreshold: settings.burnrateThreshold)
        }
        return snapshot.overallStatus
    }

    /// Current theme mode from settings
    private var currentThemeMode: ThemeMode {
        ThemeMode(rawValue: settings.themeMode) ?? .system
    }

    #if !MAS_BUILD
    private func startSessionScanner() {
        sessionScannerTask?.cancel()
        sessionScanner.stop()

        sessionScannerTask = Task {
            let events = sessionScanner.start()
            AppLog.hooks.info("Session file scanner started")
            for await event in events {
                await MainActor.run {
                    sessionMonitor.processEvent(event)
                    sendSessionNotification(for: event)
                }
            }
        }
    }

    private func startHookServer(installHooks: Bool = true) {
        // Cancel any existing server task
        hookServerTask?.cancel()
        hookServer.stop()

        // Only install hooks when explicitly enabled (session event forwarding)
        if installHooks {
            do {
                try HookInstaller.install()
                AppLog.hooks.info("Hooks installed into Claude settings")
            } catch {
                AppLog.hooks.error("Failed to install hooks: \(error.localizedDescription)")
            }
        }

        hookServerTask = Task {
            do {
                let events = try await hookServer.start()
                AppLog.hooks.info("Hook server started, listening for events")
                for await event in events {
                    await MainActor.run {
                        sessionMonitor.processEvent(event)
                        sendSessionNotification(for: event)
                    }
                }
            } catch {
                AppLog.hooks.error("Failed to start hook server: \(error.localizedDescription)")
            }
        }
    }

    func stopHookServer() {
        hookServerTask?.cancel()
        hookServerTask = nil
        hookServer.stop()
        try? HookInstaller.uninstall()
    }

    @MainActor private func sendSessionNotification(for event: SessionEvent) {
        let projectName = (event.cwd as NSString).lastPathComponent

        switch event.eventName {
        case .sessionStart:
            Task {
                try? await sessionAlertSender.send(
                    title: "Claude Code Started",
                    body: "Session started in \(projectName)",
                    categoryIdentifier: "SESSION_START"
                )
            }
        case .sessionEnd:
            let taskCount = sessionMonitor.recentSessions.first?.completedTaskCount ?? 0
            let duration = sessionMonitor.recentSessions.first?.durationDescription ?? ""
            let summary = taskCount > 0
                ? "Completed \(taskCount) task\(taskCount == 1 ? "" : "s") in \(duration)"
                : "Session ended after \(duration)"
            Task {
                try? await sessionAlertSender.send(
                    title: "Claude Code Finished",
                    body: "\(projectName) — \(summary)",
                    categoryIdentifier: "SESSION_END"
                )
            }
        default:
            break
        }
    }
    #endif

    private func writeWidgetData() {
        let snapshots = monitor.enabledProviders
            .compactMap(\.snapshot)
            .filter { !$0.quotas.isEmpty || $0.costUsage != nil }
            .map { WidgetProviderSnapshot(from: $0) }
        WidgetDataStore().write(snapshots)
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(monitor: monitor, sessionMonitor: sessionMonitor)
                .appThemeProvider(themeModeId: settings.themeMode)
                .task {
                    // Initial refresh + start monitoring
                    await monitor.refreshAll()
                    writeWidgetData()
                    for await _ in monitor.startMonitoring(interval: .seconds(150)) {
                        writeWidgetData()
                    }
                }
                .task(id: "snapshot-save") {
                    // Save snapshots after each refresh cycle
                    BurnrateSnapshotStore.shared.save(from: monitor)

                    #if ENABLE_CLOUDSYNC
                    // Push to CloudKit for iOS companion + widgets (best-effort)
                    let snapshots = monitor.enabledProviders.compactMap(\.snapshot)
                    if !snapshots.isEmpty {
                        Task.detached {
                            do {
                                try await cloudSyncWriter.publish(snapshots)
                            } catch {
                                AppLog.network.warning("CloudKit sync failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    #endif
                }
        } label: {
            BurnrateMenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }

}

// MARK: - MAS Build Helpers

#if MAS_BUILD
/// No-op cookie provider for MAS build (browser cookie access unavailable in sandbox)
private struct NoOpCookieProvider: AlibabaCookieProviding {
    func extractBrowserCookies() -> String? { nil }
}
#endif

/// The menu bar icon that reflects the overall quota status.
/// When a Claude Code session is active, shows a terminal icon with phase color.
/// Uses theme's `statusBarIconName` if set, otherwise shows status-based icons.
struct StatusBarIcon: View {
    let status: QuotaStatus
    var activeSession: ClaudeSession? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        if let session = activeSession {
            // Active session: show terminal icon with phase color
            HStack(spacing: 3) {
                Image(systemName: "terminal.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(sessionPhaseColor(session.phase))
                Image(systemName: iconName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(iconColor)
            }
        } else {
            Image(systemName: iconName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        // Use theme's custom icon if provided
        if let themeIcon = theme.statusBarIconName {
            return themeIcon
        }
        // Otherwise use status-based icon
        switch status {
        case .depleted:
            return "chart.bar.xaxis"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .warning, .healthy:
            return "chart.bar.fill"
        }
    }

    private var iconColor: Color {
        theme.statusColor(for: status)
    }

    private func sessionPhaseColor(_ phase: ClaudeSession.Phase) -> Color {
        phase.color(providerColor: ProviderDisplay.color(for: "claude"))
    }
}

// MARK: - StatusBarIcon Preview

#Preview("StatusBarIcon - All States") {
    HStack(spacing: 30) {
        VStack {
            StatusBarIcon(status: .healthy)
            Text("HEALTHY")
                .font(.caption)
                .foregroundStyle(.green)
        }
        VStack {
            StatusBarIcon(status: .warning)
            Text("WARNING")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        VStack {
            StatusBarIcon(status: .critical)
            Text("CRITICAL")
                .font(.caption)
                .foregroundStyle(.red)
        }
        VStack {
            StatusBarIcon(status: .depleted)
            Text("DEPLETED")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
    .padding(40)
    .background(Color.black)
}
