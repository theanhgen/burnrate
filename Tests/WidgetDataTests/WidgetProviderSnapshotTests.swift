import Testing
import Foundation
@testable import WidgetData

@Suite("WidgetProviderSnapshot Tests")
struct WidgetProviderSnapshotTests {

    // MARK: - Identity Tests

    @Test
    func `id is derived from providerId`() {
        let snapshot = WidgetProviderSnapshot(
            providerId: "claude",
            displayName: "Claude",
            capturedAt: Date(),
            tierBadge: nil,
            primaryQuota: nil,
            secondaryQuota: nil,
            cost: nil,
            overallStatus: "healthy"
        )

        #expect(snapshot.id == "claude")
    }

    // MARK: - Codable Round-Trip Tests

    @Test
    func `encodes and decodes correctly`() throws {
        let original = WidgetProviderSnapshot(
            providerId: "claude",
            displayName: "Claude",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tierBadge: "MAX",
            primaryQuota: WidgetQuota(
                label: "Session",
                percentRemaining: 85.5,
                status: "healthy",
                resetDescription: "Resets in 3h"
            ),
            secondaryQuota: WidgetQuota(
                label: "Weekly",
                percentRemaining: 60.0,
                status: "warning",
                resetDescription: nil
            ),
            cost: WidgetCost(
                formattedCost: "$12.50",
                formattedBudget: "$50.00",
                percentUsed: 25.0
            ),
            overallStatus: "healthy"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetProviderSnapshot.self, from: data)

        #expect(decoded.providerId == "claude")
        #expect(decoded.displayName == "Claude")
        #expect(decoded.tierBadge == "MAX")
        #expect(decoded.primaryQuota?.percentRemaining == 85.5)
        #expect(decoded.secondaryQuota?.label == "Weekly")
        #expect(decoded.cost?.formattedCost == "$12.50")
        #expect(decoded.overallStatus == "healthy")
    }

    @Test
    func `encodes and decodes with nil optional fields`() throws {
        let original = WidgetProviderSnapshot(
            providerId: "codex",
            displayName: "Codex",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tierBadge: nil,
            primaryQuota: nil,
            secondaryQuota: nil,
            cost: nil,
            overallStatus: "critical"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetProviderSnapshot.self, from: data)

        #expect(decoded.tierBadge == nil)
        #expect(decoded.primaryQuota == nil)
        #expect(decoded.secondaryQuota == nil)
        #expect(decoded.cost == nil)
    }
}

@Suite("WidgetQuota Tests")
struct WidgetQuotaTests {

    @Test
    func `encodes and decodes correctly`() throws {
        let original = WidgetQuota(
            label: "Session",
            percentRemaining: 42.0,
            status: "warning",
            resetDescription: "Resets in 1h"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetQuota.self, from: data)

        #expect(decoded.label == "Session")
        #expect(decoded.percentRemaining == 42.0)
        #expect(decoded.status == "warning")
        #expect(decoded.resetDescription == "Resets in 1h")
    }

    @Test
    func `handles nil resetDescription`() throws {
        let original = WidgetQuota(
            label: "Monthly",
            percentRemaining: 100,
            status: "healthy",
            resetDescription: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetQuota.self, from: data)

        #expect(decoded.resetDescription == nil)
    }
}

@Suite("WidgetCost Tests")
struct WidgetCostTests {

    @Test
    func `encodes and decodes correctly`() throws {
        let original = WidgetCost(
            formattedCost: "$25.00",
            formattedBudget: "$100.00",
            percentUsed: 25.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetCost.self, from: data)

        #expect(decoded.formattedCost == "$25.00")
        #expect(decoded.formattedBudget == "$100.00")
        #expect(decoded.percentUsed == 25.0)
    }

    @Test
    func `handles nil budget and percentUsed`() throws {
        let original = WidgetCost(
            formattedCost: "$5.00",
            formattedBudget: nil,
            percentUsed: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetCost.self, from: data)

        #expect(decoded.formattedBudget == nil)
        #expect(decoded.percentUsed == nil)
    }
}
