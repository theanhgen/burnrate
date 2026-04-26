import Foundation

/// Minimal least-squares linear regression: y = slope * x + intercept.
public struct LinearRegression: Sendable {
    public let slope: Double
    public let intercept: Double

    /// Fits a line to (x, y) pairs. Returns nil if fewer than 2 points or zero variance in x.
    public static func fit(points: [(x: Double, y: Double)]) -> LinearRegression? {
        let n = Double(points.count)
        guard n >= 2 else { return nil }

        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        let sumXY = points.reduce(0.0) { $0 + $1.x * $1.y }
        let sumX2 = points.reduce(0.0) { $0 + $1.x * $1.x }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        return LinearRegression(slope: slope, intercept: intercept)
    }

    /// Predicts y for a given x.
    public func predict(x: Double) -> Double {
        slope * x + intercept
    }
}
