import Foundation
import Mockable

/// Domain protocol for alerting users about quota changes.
/// Implementations decide how to alert (notifications, sounds, etc.).
@Mockable
public protocol QuotaAlerter: Sendable {
    /// Requests permission to send alerts to the user.
    /// Returns true if permission was granted.
    func requestPermission() async -> Bool

    /// Called when a provider's quota status changes.
    /// Implementations should alert users if the status degraded.
    func alert(providerId: String, previousStatus: QuotaStatus, currentStatus: QuotaStatus) async

    /// Called with a forecast to proactively alert before quota depletion.
    /// Default implementation is a no-op for backward compatibility.
    func alertIfApproaching(providerId: String, forecast: QuotaForecast, horizon: TimeInterval) async
}

extension QuotaAlerter {
    public func alertIfApproaching(providerId: String, forecast: QuotaForecast, horizon: TimeInterval) async {
        // Default no-op
    }
}
