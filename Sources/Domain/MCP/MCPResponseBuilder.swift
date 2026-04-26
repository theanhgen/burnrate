import Foundation

/// Transforms live QuotaMonitor data into MCP response DTOs.
public enum MCPResponseBuilder {

    private static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - QuotaStatusResponse

    public static func buildStatusResponse(
        providers: [any AIProvider],
        overallStatus: QuotaStatus
    ) -> QuotaStatusResponse {
        QuotaStatusResponse(
            overallStatus: statusString(overallStatus),
            providers: providers.map { buildProviderSummary($0) },
            capturedAt: formatISO8601( Date())
        )
    }

    // MARK: - ProviderDetailResponse

    public static func buildDetailResponse(provider: any AIProvider) -> ProviderDetailResponse? {
        guard let snapshot = provider.snapshot else { return nil }

        let nonModelQuotas = snapshot.quotas.filter { quota in
            if case .modelSpecific = quota.quotaType { return false }
            return true
        }

        return ProviderDetailResponse(
            id: provider.id,
            name: provider.name,
            status: statusString(snapshot.overallStatus),
            accountTier: snapshot.accountTier?.badgeText,
            quotas: nonModelQuotas.map { buildQuotaDetail($0) },
            modelQuotas: snapshot.modelSpecificQuotas.map { buildModelQuotaSummary($0) },
            costUsage: snapshot.costUsage.map { buildCostSummary($0) },
            capturedAt: formatISO8601(snapshot.capturedAt),
            snapshotAge: snapshot.ageDescription
        )
    }

    // MARK: - Provider Summary

    private static func buildProviderSummary(_ provider: any AIProvider) -> ProviderSummary {
        let snapshot = provider.snapshot

        let nonModelQuotas = (snapshot?.quotas ?? []).filter { quota in
            if case .modelSpecific = quota.quotaType { return false }
            return true
        }

        // Report "unknown" when no snapshot exists instead of misleading "healthy"
        let status = snapshot != nil ? statusString(snapshot!.overallStatus) : "unknown"

        return ProviderSummary(
            id: provider.id,
            name: provider.name,
            status: status,
            accountTier: snapshot?.accountTier?.badgeText,
            snapshotAge: snapshot?.ageDescription,
            quotas: nonModelQuotas.map { buildQuotaSummary($0) },
            modelQuotas: (snapshot?.modelSpecificQuotas ?? []).map { buildModelQuotaSummary($0) },
            costUsage: snapshot?.costUsage.map { buildCostSummary($0) }
        )
    }

    // MARK: - Quota Helpers

    private static func buildQuotaSummary(_ quota: UsageQuota) -> QuotaSummary {
        QuotaSummary(
            type: quota.quotaType.displayName,
            percentRemaining: round(quota.percentRemaining * 10) / 10,
            status: statusString(quota.status),
            resetsIn: quota.resetDescription,
            burnRate: quota.burnRate.map { round($0 * 100) / 100 }
        )
    }

    private static func buildQuotaDetail(_ quota: UsageQuota) -> QuotaDetail {
        QuotaDetail(
            type: quota.quotaType.displayName,
            percentRemaining: round(quota.percentRemaining * 10) / 10,
            percentUsed: round(quota.percentUsed * 10) / 10,
            status: statusString(quota.status),
            resetsIn: quota.resetDescription,
            resetsAt: quota.resetsAt.map { formatISO8601( $0) },
            burnRate: quota.burnRate.map { round($0 * 100) / 100 },
            pace: paceString(quota.pace),
            paceInsight: quota.paceInsight
        )
    }

    private static func buildModelQuotaSummary(_ quota: UsageQuota) -> ModelQuotaSummary {
        ModelQuotaSummary(
            model: quota.quotaType.modelName ?? "unknown",
            percentRemaining: round(quota.percentRemaining * 10) / 10,
            status: statusString(quota.status)
        )
    }

    private static func buildCostSummary(_ cost: CostUsage) -> CostSummary {
        CostSummary(
            totalCost: cost.formattedCost,
            budget: cost.formattedBudget,
            budgetPercentUsed: cost.budgetPercentUsedFromBuiltIn
        )
    }

    // MARK: - String Conversions

    private static func statusString(_ status: QuotaStatus) -> String {
        switch status {
        case .healthy: "healthy"
        case .warning: "warning"
        case .critical: "critical"
        case .depleted: "depleted"
        }
    }

    private static func paceString(_ pace: UsagePace) -> String {
        switch pace {
        case .ahead: "ahead"
        case .behind: "behind"
        case .onPace: "on_pace"
        case .unknown: "unknown"
        }
    }
}
