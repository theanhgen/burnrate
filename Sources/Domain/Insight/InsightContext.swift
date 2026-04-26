import Foundation

/// Everything an insight generator needs to produce insights.
/// Bundled as a value type for testability — construct with known data, assert on output.
public struct InsightContext: Sendable {
    /// Provider ID; nil for cross-provider insights
    public let providerId: String?
    /// Current live quota data
    public let liveQuotas: [UsageQuota]
    /// Statistics from the last 7 days of snapshots
    public let currentPeriod: SnapshotSummary
    /// Statistics from 7-14 days ago (for trend comparison)
    public let previousPeriod: SnapshotSummary
    /// Forecast from linear regression (if available)
    public let forecast: QuotaForecast?
    /// Daily usage report (Claude only, from JSONL analysis)
    public let dailyReport: DailyUsageReport?
    /// Reference time for calculations (injectable for testing)
    public let now: Date

    public init(
        providerId: String? = nil,
        liveQuotas: [UsageQuota] = [],
        currentPeriod: SnapshotSummary = .empty,
        previousPeriod: SnapshotSummary = .empty,
        forecast: QuotaForecast? = nil,
        dailyReport: DailyUsageReport? = nil,
        now: Date = Date()
    ) {
        self.providerId = providerId
        self.liveQuotas = liveQuotas
        self.currentPeriod = currentPeriod
        self.previousPeriod = previousPeriod
        self.forecast = forecast
        self.dailyReport = dailyReport
        self.now = now
    }
}
