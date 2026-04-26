import Foundation

/// Lightweight Codable model for widget timeline data.
/// Flattened from Domain's UsageSnapshot for minimal serialization cost.
public struct WidgetProviderSnapshot: Codable, Sendable, Identifiable {
    public var id: String { providerId }

    public let providerId: String
    public let displayName: String
    public let capturedAt: Date

    /// Account tier badge text (e.g., "MAX", "PRO", "API"), nil if unknown
    public let tierBadge: String?

    /// Primary quota (session for Claude/Codex, main quota for others)
    public let primaryQuota: WidgetQuota?

    /// Secondary quota (weekly for Claude/Codex), nil for single-quota providers
    public let secondaryQuota: WidgetQuota?

    /// Cost info for API/budget accounts
    public let cost: WidgetCost?

    /// Overall status: "healthy", "warning", "critical", "depleted"
    public let overallStatus: String

    public init(
        providerId: String,
        displayName: String,
        capturedAt: Date,
        tierBadge: String?,
        primaryQuota: WidgetQuota?,
        secondaryQuota: WidgetQuota?,
        cost: WidgetCost?,
        overallStatus: String
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.capturedAt = capturedAt
        self.tierBadge = tierBadge
        self.primaryQuota = primaryQuota
        self.secondaryQuota = secondaryQuota
        self.cost = cost
        self.overallStatus = overallStatus
    }
}

public struct WidgetQuota: Codable, Sendable {
    public let label: String
    public let percentRemaining: Double
    public let status: String
    public let resetDescription: String?

    public init(
        label: String,
        percentRemaining: Double,
        status: String,
        resetDescription: String?
    ) {
        self.label = label
        self.percentRemaining = percentRemaining
        self.status = status
        self.resetDescription = resetDescription
    }
}

public struct WidgetCost: Codable, Sendable {
    public let formattedCost: String
    public let formattedBudget: String?
    public let percentUsed: Double?

    public init(
        formattedCost: String,
        formattedBudget: String?,
        percentUsed: Double?
    ) {
        self.formattedCost = formattedCost
        self.formattedBudget = formattedBudget
        self.percentUsed = percentUsed
    }
}
