import Testing
import Foundation
@testable import Domain
@testable import WidgetData

@Suite("WidgetSnapshotMapper")
struct WidgetSnapshotMapperTests {

    // MARK: - Basic Mapping

    @Test("Maps provider ID and capture time")
    func mapsProviderIdAndCaptureTime() {
        let now = Date()
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: now
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.providerId == "claude")
        #expect(widget.capturedAt == now)
    }

    @Test("Maps display names for all known providers", arguments: [
        ("claude", "Claude"),
        ("codex", "Codex"),
        ("gemini", "Gemini"),
        ("copilot", "GitHub Copilot"),
        ("antigravity", "Antigravity"),
        ("zai", "Z.ai"),
        ("bedrock", "AWS Bedrock"),
        ("ampcode", "Amp"),
        ("kimi", "Kimi"),
        ("kiro", "Kiro"),
        ("minimax", "MiniMax"),
        ("cursor", "Cursor"),
        ("mistral", "Mistral"),
    ])
    func mapsDisplayNames(providerId: String, expectedName: String) {
        let snapshot = UsageSnapshot(
            providerId: providerId,
            quotas: [],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.displayName == expectedName)
    }

    @Test("Unknown provider ID falls back to capitalized")
    func unknownProviderFallsBack() {
        let snapshot = UsageSnapshot(
            providerId: "newprovider",
            quotas: [],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.displayName == "Newprovider")
    }

    // MARK: - Tier Badge

    @Test("Maps Claude Max tier badge")
    func mapsClaudeMaxTierBadge() {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date(),
            accountTier: .claudeMax
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.tierBadge == "MAX")
    }

    @Test("Nil tier badge when no account tier")
    func nilTierBadgeWhenNoTier() {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.tierBadge == nil)
    }

    // MARK: - Quota Mapping

    @Test("Maps session quota as primary")
    func mapsSessionQuotaAsPrimary() {
        let sessionQuota = UsageQuota(
            percentRemaining: 72.5,
            quotaType: .session,
            providerId: "claude",
            resetsAt: Date().addingTimeInterval(3600)
        )
        let weeklyQuota = UsageQuota(
            percentRemaining: 45,
            quotaType: .weekly,
            providerId: "claude"
        )
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [sessionQuota, weeklyQuota],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.primaryQuota?.label == "Session")
        #expect(widget.primaryQuota?.percentRemaining == 72.5)
    }

    @Test("Maps weekly quota as secondary")
    func mapsWeeklyQuotaAsSecondary() {
        let sessionQuota = UsageQuota(
            percentRemaining: 72.5,
            quotaType: .session,
            providerId: "claude"
        )
        let weeklyQuota = UsageQuota(
            percentRemaining: 45,
            quotaType: .weekly,
            providerId: "claude"
        )
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [sessionQuota, weeklyQuota],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.secondaryQuota?.label == "Weekly")
        #expect(widget.secondaryQuota?.percentRemaining == 45)
    }

    @Test("Falls back to first quota as primary when no session quota")
    func fallsBackToFirstQuota() {
        let quota = UsageQuota(
            percentRemaining: 60,
            quotaType: .modelSpecific("opus"),
            providerId: "gemini"
        )
        let snapshot = UsageSnapshot(
            providerId: "gemini",
            quotas: [quota],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.primaryQuota?.label == "Opus")
        #expect(widget.primaryQuota?.percentRemaining == 60)
        #expect(widget.secondaryQuota == nil)
    }

    @Test("No quotas results in nil primary and secondary")
    func noQuotasResultsInNil() {
        let snapshot = UsageSnapshot(
            providerId: "bedrock",
            quotas: [],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.primaryQuota == nil)
        #expect(widget.secondaryQuota == nil)
    }

    // MARK: - Quota Status Mapping

    @Test("Maps quota status string", arguments: [
        (85.0, "healthy"),
        (35.0, "warning"),
        (10.0, "critical"),
        (0.0, "depleted"),
    ])
    func mapsQuotaStatus(percentRemaining: Double, expectedStatus: String) {
        let quota = UsageQuota(
            percentRemaining: percentRemaining,
            quotaType: .session,
            providerId: "claude"
        )

        let widgetQuota = WidgetQuota(from: quota)

        #expect(widgetQuota.status == expectedStatus)
    }

    @Test("Maps reset description from quota")
    func mapsResetDescription() {
        let quota = UsageQuota(
            percentRemaining: 50,
            quotaType: .session,
            providerId: "claude",
            resetsAt: Date().addingTimeInterval(7200)
        )

        let widgetQuota = WidgetQuota(from: quota)

        #expect(widgetQuota.resetDescription != nil)
        #expect(widgetQuota.resetDescription!.hasPrefix("Resets in"))
    }

    // MARK: - Overall Status

    @Test("Overall status reflects worst quota")
    func overallStatusReflectsWorstQuota() {
        let healthy = UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude")
        let critical = UsageQuota(percentRemaining: 10, quotaType: .weekly, providerId: "claude")
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [healthy, critical],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.overallStatus == "critical")
    }

    @Test("Empty quotas default to healthy")
    func emptyQuotasDefaultToHealthy() {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.overallStatus == "healthy")
    }

    // MARK: - Cost Mapping

    @Test("Maps cost usage")
    func mapsCostUsage() {
        let cost = CostUsage(
            totalCost: 12.50,
            budget: 100.00,
            apiDuration: 600,
            providerId: "claude"
        )
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date(),
            costUsage: cost
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.cost != nil)
        #expect(widget.cost?.formattedCost.contains("12.50") == true)
        #expect(widget.cost?.formattedBudget?.contains("100.00") == true)
        #expect(widget.cost?.percentUsed == 12.5)
    }

    @Test("Nil cost when no cost usage")
    func nilCostWhenNoCostUsage() {
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        )

        let widget = WidgetProviderSnapshot(from: snapshot)

        #expect(widget.cost == nil)
    }
}
