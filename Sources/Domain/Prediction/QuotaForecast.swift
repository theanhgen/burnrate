import Foundation

/// Confidence in the forecast based on data quality.
public enum ForecastConfidence: Sendable {
    case low       // < 5 data points
    case medium    // 5-20 data points
    case high      // > 20 data points
}

/// Predicts when a quota will be depleted based on historical snapshots.
public struct QuotaForecast: Sendable {
    /// When the quota is expected to hit 100% used. Nil if on track to not deplete.
    public let estimatedDepletionDate: Date?

    /// Current burn rate in percent-used per hour.
    public let burnRatePerHour: Double

    /// Confidence based on number of data points.
    public let confidence: ForecastConfidence

    /// Builds a forecast from historical snapshot data.
    /// - Parameters:
    ///   - points: Pairs of (timestamp, percentUsed) sorted by time.
    ///   - now: Current time for projection.
    /// - Returns: Forecast, or nil if insufficient data.
    public static func from(
        points: [(timestamp: Date, percentUsed: Double)],
        now: Date = Date()
    ) -> QuotaForecast? {
        // Trim to points after the last quota reset (large drop in usage)
        let trimmed = trimToCurrentPeriod(points)
        guard trimmed.count >= 2 else { return nil }

        let referenceTime = trimmed[0].timestamp.timeIntervalSince1970
        let regressionPoints = trimmed.map { p in
            (x: (p.timestamp.timeIntervalSince1970 - referenceTime) / 3600.0, y: p.percentUsed)
        }

        guard let regression = LinearRegression.fit(points: regressionPoints) else { return nil }

        let confidence: ForecastConfidence
        switch trimmed.count {
        case ..<5: confidence = .low
        case 5...20: confidence = .medium
        default: confidence = .high
        }

        let ratePerHour = regression.slope

        // If rate is zero or negative (usage decreasing), no depletion
        guard ratePerHour > 0 else {
            return QuotaForecast(
                estimatedDepletionDate: nil,
                burnRatePerHour: max(ratePerHour, 0),
                confidence: confidence
            )
        }

        // Project when percentUsed hits 100
        let nowX = (now.timeIntervalSince1970 - referenceTime) / 3600.0
        let currentProjected = regression.predict(x: nowX)
        let remaining = 100.0 - currentProjected

        if remaining <= 0 {
            // Already at or past 100%
            return QuotaForecast(
                estimatedDepletionDate: now,
                burnRatePerHour: ratePerHour,
                confidence: confidence
            )
        }

        let hoursUntilDepletion = remaining / ratePerHour
        let depletionDate = now.addingTimeInterval(hoursUntilDepletion * 3600)

        return QuotaForecast(
            estimatedDepletionDate: depletionDate,
            burnRatePerHour: ratePerHour,
            confidence: confidence
        )
    }

    /// Human-readable depletion description.
    public var depletionDescription: String {
        description(now: Date())
    }

    /// Human-readable depletion description relative to a reference time.
    public func description(now: Date) -> String {
        guard let depletion = estimatedDepletionDate else {
            return "On track"
        }

        let remaining = depletion.timeIntervalSince(now)
        if remaining <= 0 {
            return "Depleted"
        }

        let hours = remaining / 3600
        if hours < 1 {
            let mins = Int(remaining / 60)
            return "~\(max(mins, 1))m remaining"
        } else if hours < 24 {
            return "~\(Int(hours))h remaining"
        } else {
            return String(format: "~%.1f days remaining", hours / 24)
        }
    }

    /// Trims points to only those after the last quota reset.
    /// A reset is detected as a drop of 30+ percentage points between consecutive readings.
    private static func trimToCurrentPeriod(
        _ points: [(timestamp: Date, percentUsed: Double)]
    ) -> [(timestamp: Date, percentUsed: Double)] {
        var lastResetIndex = 0
        for i in 1..<points.count {
            if points[i].percentUsed < points[i - 1].percentUsed - 30 {
                lastResetIndex = i
            }
        }
        return Array(points[lastResetIndex...])
    }
}
