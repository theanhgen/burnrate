import Foundation
import Domain
import Mockable

// MARK: - Internal Protocol (for testability)

/// Internal protocol for sending system alerts. Enables testing without UNUserNotificationCenter.
@Mockable
protocol AlertSender: Sendable {
    func requestPermission() async -> Bool
    func send(title: String, body: String, categoryIdentifier: String) async throws
}

// MARK: - NotificationAlerter

/// Alerts users when their AI quota status degrades.
/// Sends system notifications for warning, critical, and depleted states.
public final class NotificationAlerter: QuotaAlerter, @unchecked Sendable {

    private let alertSender: AlertSender
    private let policy: ProactiveAlertPolicy
    private let settingsRepository: any AppSettingsRepository

    /// Tracks last proactive alert time per provider to enforce cooldown.
    private var lastProactiveAlert: [String: Date] = [:]
    private let lock = NSLock()

    /// Public initializer - uses system alerts
    public init(settingsRepository: any AppSettingsRepository) {
        self.alertSender = SystemAlertSender()
        self.policy = ProactiveAlertPolicy()
        self.settingsRepository = settingsRepository
    }

    /// Internal initializer for testing
    init(
        alertSender: AlertSender,
        settingsRepository: any AppSettingsRepository,
        policy: ProactiveAlertPolicy = ProactiveAlertPolicy()
    ) {
        self.alertSender = alertSender
        self.settingsRepository = settingsRepository
        self.policy = policy
    }

    // MARK: - Public API

    /// Requests permission to send quota alerts.
    public func requestPermission() async -> Bool {
        AppLog.notifications.debug("Requesting alert permission...")
        let granted = await alertSender.requestPermission()
        AppLog.notifications.info("Alert permission: \(granted ? "granted" : "denied")")
        return granted
    }

    // MARK: - QuotaAlerter

    public func alert(providerId: String, previousStatus: QuotaStatus, currentStatus: QuotaStatus) async {
        AppLog.notifications.debug("Status change: \(providerId) \(previousStatus) -> \(currentStatus)")

        // Only alert on degradation (getting worse)
        guard currentStatus > previousStatus else {
            AppLog.notifications.debug("Status improved or same, skipping alert")
            return
        }

        guard shouldAlert(for: currentStatus) else {
            AppLog.notifications.debug("Status \(currentStatus) does not require alert")
            return
        }

        let providerName = providerDisplayName(for: providerId)
        let title = "\(providerName) Quota Alert"
        let body = alertBody(for: currentStatus, providerName: providerName)

        AppLog.notifications.notice("Sending quota alert for \(providerId): \(currentStatus)")

        do {
            try await alertSender.send(title: title, body: body, categoryIdentifier: "QUOTA_ALERT")
            AppLog.notifications.info("Alert sent successfully")
        } catch {
            AppLog.notifications.error("Failed to send alert: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers (internal for testability)

    func shouldAlert(for status: QuotaStatus) -> Bool {
        switch status {
        case .warning, .critical, .depleted:
            return true
        case .healthy:
            return false
        }
    }

    func providerDisplayName(for providerId: String) -> String {
        switch providerId {
        case "claude": return "Claude"
        case "codex": return "Codex"
        case "gemini": return "Gemini"
        case "copilot": return "GitHub Copilot"
        case "antigravity": return "Antigravity"
        case "zai": return "Z.ai"
        case "bedrock": return "AWS Bedrock"
        default: return providerId.capitalized
        }
    }

    func alertBody(for status: QuotaStatus, providerName: String) -> String {
        switch status {
        case .warning:
            return "Your \(providerName) quota is running low. Consider pacing your usage."
        case .critical:
            return "Your \(providerName) quota is critically low! Save important work."
        case .depleted:
            return "Your \(providerName) quota is depleted. Usage may be blocked."
        case .healthy:
            return "Your \(providerName) quota has recovered."
        }
    }

    // MARK: - Proactive Alerts

    public func alertIfApproaching(providerId: String, forecast: QuotaForecast, horizon: TimeInterval) async {
        guard settingsRepository.proactiveAlertsEnabled() else { return }
        guard policy.shouldAlert(forecast: forecast, horizon: horizon) else { return }

        // Enforce cooldown
        let now = Date()
        let shouldSkip = lock.withLock {
            if let last = lastProactiveAlert[providerId],
               now.timeIntervalSince(last) < policy.cooldown {
                return true
            }
            return false
        }
        if shouldSkip { return }

        let providerName = providerDisplayName(for: providerId)
        let title = "\(providerName) Quota Forecast"
        let body = "Your \(providerName) quota is projected to deplete soon. \(forecast.depletionDescription)."

        AppLog.notifications.notice("Sending proactive alert for \(providerId): \(forecast.depletionDescription)")

        do {
            try await alertSender.send(title: title, body: body, categoryIdentifier: "QUOTA_FORECAST")
            // Record cooldown only after successful send
            lock.withLock {
                lastProactiveAlert[providerId] = Date()
            }
        } catch {
            AppLog.notifications.error("Failed to send proactive alert: \(error.localizedDescription)")
        }
    }
}
