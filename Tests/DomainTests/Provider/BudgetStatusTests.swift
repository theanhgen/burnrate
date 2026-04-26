import Testing
import Foundation
@testable import Domain

@Suite("BudgetStatus Tests")
struct BudgetStatusTests {

    // MARK: - Factory Method Tests

    @Test
    func `within budget when cost is below 80 percent`() {
        let status = BudgetStatus.from(cost: 50, budget: 100)
        #expect(status == .withinBudget)
    }

    @Test
    func `within budget at exactly 0 cost`() {
        let status = BudgetStatus.from(cost: 0, budget: 100)
        #expect(status == .withinBudget)
    }

    @Test
    func `within budget at 79 percent`() {
        let status = BudgetStatus.from(cost: 79, budget: 100)
        #expect(status == .withinBudget)
    }

    @Test
    func `approaching limit at exactly 80 percent`() {
        let status = BudgetStatus.from(cost: 80, budget: 100)
        #expect(status == .approachingLimit)
    }

    @Test
    func `approaching limit at 99 percent`() {
        let status = BudgetStatus.from(cost: 99, budget: 100)
        #expect(status == .approachingLimit)
    }

    @Test
    func `over budget at exactly 100 percent`() {
        let status = BudgetStatus.from(cost: 100, budget: 100)
        #expect(status == .overBudget)
    }

    @Test
    func `over budget at 150 percent`() {
        let status = BudgetStatus.from(cost: 150, budget: 100)
        #expect(status == .overBudget)
    }

    @Test
    func `within budget when budget is zero`() {
        let status = BudgetStatus.from(cost: 50, budget: 0)
        #expect(status == .withinBudget)
    }

    @Test
    func `within budget when budget is negative`() {
        let status = BudgetStatus.from(cost: 50, budget: -10)
        #expect(status == .withinBudget)
    }

    // MARK: - Badge Text Tests

    @Test
    func `within budget badge text`() {
        #expect(BudgetStatus.withinBudget.badgeText == "ON TRACK")
    }

    @Test
    func `approaching limit badge text`() {
        #expect(BudgetStatus.approachingLimit.badgeText == "NEAR LIMIT")
    }

    @Test
    func `over budget badge text`() {
        #expect(BudgetStatus.overBudget.badgeText == "OVER BUDGET")
    }

    // MARK: - Needs Attention Tests

    @Test
    func `within budget does not need attention`() {
        #expect(BudgetStatus.withinBudget.needsAttention == false)
    }

    @Test
    func `approaching limit needs attention`() {
        #expect(BudgetStatus.approachingLimit.needsAttention == true)
    }

    @Test
    func `over budget needs attention`() {
        #expect(BudgetStatus.overBudget.needsAttention == true)
    }

    // MARK: - Severity Tests

    @Test
    func `severity increases with worse status`() {
        #expect(BudgetStatus.withinBudget.severity == 0)
        #expect(BudgetStatus.approachingLimit.severity == 1)
        #expect(BudgetStatus.overBudget.severity == 2)
    }

    // MARK: - Comparable Tests

    @Test
    func `within budget is less than approaching limit`() {
        #expect(BudgetStatus.withinBudget < BudgetStatus.approachingLimit)
    }

    @Test
    func `approaching limit is less than over budget`() {
        #expect(BudgetStatus.approachingLimit < BudgetStatus.overBudget)
    }

    @Test
    func `within budget is less than over budget`() {
        #expect(BudgetStatus.withinBudget < BudgetStatus.overBudget)
    }

    @Test
    func `same status is not less than itself`() {
        #expect(!(BudgetStatus.withinBudget < BudgetStatus.withinBudget))
    }
}
