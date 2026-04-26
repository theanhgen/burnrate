import Foundation

/// Determines whether a proactive alert should fire based on quota forecast.
/// Unlike reactive alerts (which fire on status change), proactive alerts fire
/// when a forecast predicts depletion within a configurable horizon.
public struct ProactiveAlertPolicy: Sendable {
    /// How far ahead to look for session quota depletion (default: 1 hour)
    public let sessionHorizon: TimeInterval

    /// How far ahead to look for weekly quota depletion (default: 12 hours)
    public let weeklyHorizon: TimeInterval

    /// Minimum time between proactive alerts for the same provider (default: 30 minutes)
    public let cooldown: TimeInterval

    public init(
        sessionHorizon: TimeInterval = 3600,
        weeklyHorizon: TimeInterval = 12 * 3600,
        cooldown: TimeInterval = 1800
    ) {
        self.sessionHorizon = sessionHorizon
        self.weeklyHorizon = weeklyHorizon
        self.cooldown = cooldown
    }

    /// Returns true if the forecast predicts depletion within the given horizon.
    public func shouldAlert(forecast: QuotaForecast, horizon: TimeInterval, now: Date = Date()) -> Bool {
        guard let depletion = forecast.estimatedDepletionDate else { return false }
        let timeUntil = depletion.timeIntervalSince(now)
        return timeUntil > 0 && timeUntil <= horizon
    }
}
