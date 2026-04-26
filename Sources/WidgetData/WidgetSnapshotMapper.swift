import Domain
import Foundation

extension WidgetProviderSnapshot {
    public init(from snapshot: UsageSnapshot) {
        self.providerId = snapshot.providerId
        self.displayName = Self.displayName(for: snapshot.providerId)
        self.capturedAt = snapshot.capturedAt
        self.tierBadge = snapshot.accountTier?.badgeText
        self.overallStatus = snapshot.overallStatus.widgetString

        self.primaryQuota = snapshot.sessionQuota.map { WidgetQuota(from: $0) }
            ?? snapshot.quotas.first.map { WidgetQuota(from: $0) }
        self.secondaryQuota = snapshot.weeklyQuota.map { WidgetQuota(from: $0) }

        self.cost = snapshot.costUsage.map { WidgetCost(from: $0) }
    }

    private static func displayName(for providerId: String) -> String {
        switch providerId {
        case "claude": "Claude"
        case "codex": "Codex"
        case "gemini": "Gemini"
        case "copilot": "GitHub Copilot"
        case "antigravity": "Antigravity"
        case "zai": "Z.ai"
        case "bedrock": "AWS Bedrock"
        case "ampcode": "Amp"
        case "kimi": "Kimi"
        case "kiro": "Kiro"
        case "minimax": "MiniMax"
        case "cursor": "Cursor"
        case "mistral": "Mistral"
        default: providerId.capitalized
        }
    }
}

extension WidgetQuota {
    init(from quota: UsageQuota) {
        self.label = quota.quotaType.displayName
        self.percentRemaining = quota.percentRemaining
        self.status = quota.status.widgetString
        self.resetDescription = quota.resetDescription
    }
}

extension WidgetCost {
    init(from cost: CostUsage) {
        self.formattedCost = cost.formattedCost
        self.formattedBudget = cost.formattedBudget
        self.percentUsed = cost.budgetPercentUsedFromBuiltIn
    }
}

extension QuotaStatus {
    var widgetString: String {
        switch self {
        case .healthy: "healthy"
        case .warning: "warning"
        case .critical: "critical"
        case .depleted: "depleted"
        }
    }
}
