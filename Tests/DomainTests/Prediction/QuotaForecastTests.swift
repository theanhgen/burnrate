import Testing
import Foundation
@testable import Domain

@Suite
struct QuotaForecastTests {

    @Test
    func `predicts depletion for steady usage`() {
        let now = Date()
        // Usage going from 50% to 75% over 5 hours = 5%/hr
        let points: [(timestamp: Date, percentUsed: Double)] = (0..<6).map { i in
            (timestamp: now.addingTimeInterval(Double(i) * -3600), percentUsed: 75 - Double(i) * 5)
        }.reversed()

        let forecast = QuotaForecast.from(points: points, now: now)!

        #expect(forecast.estimatedDepletionDate != nil)
        #expect(abs(forecast.burnRatePerHour - 5.0) < 0.1)
        // At 75% with 5%/hr, ~5 hours to depletion
        let hoursToDepletion = forecast.estimatedDepletionDate!.timeIntervalSince(now) / 3600
        #expect(abs(hoursToDepletion - 5.0) < 0.5)
    }

    @Test
    func `returns nil depletion for decreasing usage`() {
        let now = Date()
        let points: [(timestamp: Date, percentUsed: Double)] = [
            (timestamp: now.addingTimeInterval(-3600), percentUsed: 80),
            (timestamp: now, percentUsed: 70),
        ]

        let forecast = QuotaForecast.from(points: points, now: now)!
        #expect(forecast.estimatedDepletionDate == nil)
        #expect(forecast.depletionDescription == "On track")
    }

    @Test
    func `returns nil for insufficient data`() {
        let forecast = QuotaForecast.from(points: [
            (timestamp: Date(), percentUsed: 50),
        ])
        #expect(forecast == nil)
    }

    @Test
    func `confidence is low for few points`() {
        let now = Date()
        let points: [(timestamp: Date, percentUsed: Double)] = [
            (timestamp: now.addingTimeInterval(-3600), percentUsed: 40),
            (timestamp: now, percentUsed: 50),
        ]

        let forecast = QuotaForecast.from(points: points, now: now)!
        #expect(forecast.confidence == .low)
    }

    @Test
    func `confidence is high for many points`() {
        let now = Date()
        let points: [(timestamp: Date, percentUsed: Double)] = (0..<25).map { i in
            (timestamp: now.addingTimeInterval(Double(i) * -300), percentUsed: 50 + Double(i) * 0.5)
        }.reversed()

        let forecast = QuotaForecast.from(points: points, now: now)!
        #expect(forecast.confidence == .high)
    }

    @Test
    func `handles already depleted quota`() {
        let now = Date()
        let points: [(timestamp: Date, percentUsed: Double)] = [
            (timestamp: now.addingTimeInterval(-3600), percentUsed: 95),
            (timestamp: now, percentUsed: 105),
        ]

        let forecast = QuotaForecast.from(points: points, now: now)!
        #expect(forecast.depletionDescription == "Depleted")
    }

    @Test
    func `depletion description formats hours`() {
        let now = Date()
        let points: [(timestamp: Date, percentUsed: Double)] = [
            (timestamp: now.addingTimeInterval(-3600), percentUsed: 40),
            (timestamp: now, percentUsed: 50),
        ]

        let forecast = QuotaForecast.from(points: points, now: now)!
        // 10%/hr at 50%, 50% remaining = 5h
        #expect(forecast.description(now: now).contains("5h"))
    }
}
