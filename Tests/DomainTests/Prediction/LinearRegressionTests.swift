import Testing
import Foundation
@testable import Domain

@Suite
struct LinearRegressionTests {

    @Test
    func `fits a perfect upward line`() {
        let points: [(x: Double, y: Double)] = [(0, 0), (1, 2), (2, 4)]
        let reg = LinearRegression.fit(points: points)!

        #expect(abs(reg.slope - 2.0) < 0.001)
        #expect(abs(reg.intercept) < 0.001)
        #expect(abs(reg.predict(x: 3) - 6.0) < 0.001)
    }

    @Test
    func `fits a line with intercept`() {
        let points: [(x: Double, y: Double)] = [(0, 10), (1, 12), (2, 14)]
        let reg = LinearRegression.fit(points: points)!

        #expect(abs(reg.slope - 2.0) < 0.001)
        #expect(abs(reg.intercept - 10.0) < 0.001)
    }

    @Test
    func `returns nil for single point`() {
        let result = LinearRegression.fit(points: [(x: 1, y: 1)])
        #expect(result == nil)
    }

    @Test
    func `returns nil for empty input`() {
        let result = LinearRegression.fit(points: [])
        #expect(result == nil)
    }

    @Test
    func `returns nil for zero variance in x`() {
        let result = LinearRegression.fit(points: [(x: 5, y: 1), (x: 5, y: 2)])
        #expect(result == nil)
    }

    @Test
    func `handles negative slope`() {
        let points: [(x: Double, y: Double)] = [(0, 100), (1, 90), (2, 80)]
        let reg = LinearRegression.fit(points: points)!

        #expect(abs(reg.slope - (-10.0)) < 0.001)
    }
}
