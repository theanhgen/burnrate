import Foundation

/// Builds an ExportableSnapshot from live provider data.
public enum ExportableSnapshotBuilder {

    public static func build(
        providers: [ProviderExportInput],
        appVersion: String,
        exportedAt: Date = Date()
    ) -> ExportableSnapshot {
        let exportableProviders = providers.map { buildProvider($0) }
        return ExportableSnapshot(
            exportedAt: exportedAt,
            appVersion: appVersion,
            providers: exportableProviders
        )
    }

    private static func buildProvider(_ input: ProviderExportInput) -> ExportableProvider {
        let quotas = input.snapshot?.quotas.map { buildQuota($0) } ?? []
        let costUsage = input.snapshot?.costUsage.map { buildCostUsage($0) }
        let dailyUsage = input.snapshot?.dailyUsageReport.map { buildDailyUsage($0) }
        let bedrockUsage = input.snapshot?.bedrockUsage.map { buildBedrockUsage($0) }

        return ExportableProvider(
            id: input.id,
            name: input.name,
            status: input.snapshot?.overallStatus.exportLabel ?? "unknown",
            accountEmail: input.snapshot?.accountEmail,
            accountTier: input.snapshot?.accountTier?.displayName,
            quotas: quotas,
            costUsage: costUsage,
            dailyUsage: dailyUsage,
            bedrockUsage: bedrockUsage
        )
    }

    private static func buildQuota(_ q: UsageQuota) -> ExportableQuota {
        ExportableQuota(
            type: q.quotaType.displayName,
            percentRemaining: q.percentRemaining,
            percentUsed: q.percentUsed,
            status: q.status.exportLabel,
            resetsAt: q.resetsAt,
            resetDescription: q.resetDescription,
            pace: q.pace == .unknown ? nil : q.pace.exportLabel,
            burnRate: q.burnRate,
            dollarRemaining: q.formattedDollarRemaining
        )
    }

    private static func buildCostUsage(_ c: CostUsage) -> ExportableCostUsage {
        ExportableCostUsage(
            totalCost: c.formattedCost,
            budget: c.formattedBudget,
            budgetPercentUsed: c.budgetPercentUsedFromBuiltIn,
            apiDuration: c.formattedApiDuration,
            wallDuration: c.formattedWallDuration,
            linesAdded: c.linesAdded,
            linesRemoved: c.linesRemoved,
            resetsAt: c.resetsAt
        )
    }

    private static func buildDailyUsage(_ d: DailyUsageReport) -> ExportableDailyUsage {
        ExportableDailyUsage(
            todayCost: d.today.formattedCost,
            todayTokens: d.today.formattedTokens,
            todayWorkingTime: d.today.formattedWorkingTime,
            todaySessions: d.today.sessionCount,
            previousCost: d.previous.formattedCost,
            previousTokens: d.previous.formattedTokens,
            costDelta: d.formattedCostDelta,
            tokenDelta: d.formattedTokenDelta,
            timeDelta: d.formattedTimeDelta
        )
    }

    private static func buildBedrockUsage(_ b: BedrockUsageSummary) -> ExportableBedrockUsage {
        ExportableBedrockUsage(
            region: b.region,
            totalCost: b.formattedTotalCost,
            totalInvocations: b.totalInvocations,
            totalTokens: b.formattedTotalTokens,
            dailyBudget: b.formattedDailyBudget,
            models: b.modelUsages.map { m in
                ExportableBedrockModel(
                    name: m.model.displayName,
                    invocations: m.invocations,
                    inputTokens: m.inputTokens,
                    outputTokens: m.outputTokens,
                    cost: m.formattedCost
                )
            }
        )
    }
}

// MARK: - Input

/// Lightweight input for the builder, decoupled from AIProvider protocol.
public struct ProviderExportInput: Sendable {
    public let id: String
    public let name: String
    public let snapshot: UsageSnapshot?

    public init(id: String, name: String, snapshot: UsageSnapshot?) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }
}

// MARK: - Export Labels

extension QuotaStatus {
    var exportLabel: String {
        switch self {
        case .healthy: "healthy"
        case .warning: "warning"
        case .critical: "critical"
        case .depleted: "depleted"
        }
    }
}

extension UsagePace {
    var exportLabel: String {
        switch self {
        case .onPace: "on_pace"
        case .ahead: "ahead"
        case .behind: "behind"
        case .unknown: "unknown"
        }
    }
}
