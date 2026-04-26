import SwiftUI
import Domain

/// Displays a single provider's usage in a compact card format.
/// Adapted from burnrate's design to consume its AIProvider protocol.
struct ProviderCardView: View {
    let provider: any AIProvider
    @State private var topInsight: UsageInsight?

    private var providerColor: Color { ProviderDisplay.color(for: provider.id) }
    private var providerIcon: String { ProviderDisplay.icon(for: provider.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + name + tier + confidence badge
            HStack {
                Image(systemName: providerIcon)
                    .foregroundStyle(providerColor)
                Text(provider.name)
                    .font(.system(size: 13, weight: .semibold))
                if let tier = provider.snapshot?.accountTier {
                    Text(tier.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                ConfidenceBadge(confidence: provider.confidence)
            }

            if provider.isSyncing && provider.snapshot == nil {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else if let snapshot = provider.snapshot {
                usageContent(snapshot)
            } else if provider.lastError != nil {
                Text("Unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("No data yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .task {
            loadTopInsight()
        }
    }

    @MainActor
    private func loadTopInsight() {
        let store = BurnrateSnapshotStore.shared
        let now = Date()
        let snapshots = store.query(provider: provider.id, since: now.addingTimeInterval(-7 * 24 * 3600))
        let summary = SnapshotSummary.from(snapshots: snapshots.map { (ts: $0.ts, session: $0.session, weekly: $0.weekly) })

        // Build a lightweight forecast from session data
        let sessionSnaps = store.query(provider: provider.id, since: now.addingTimeInterval(-6 * 3600))
        let forecast: QuotaForecast? = if !sessionSnaps.isEmpty {
            QuotaForecast.from(
                points: sessionSnaps.map { (timestamp: Date(timeIntervalSince1970: $0.ts), percentUsed: Double($0.session)) },
                now: now
            )
        } else {
            nil
        }

        let context = InsightContext(
            providerId: provider.id,
            liveQuotas: provider.snapshot?.quotas ?? [],
            currentPeriod: summary,
            forecast: forecast,
            now: now
        )

        // Only show high-priority or critical insights in the compact card
        let insights = InsightEngine().evaluate(context: context)
        topInsight = insights.first { $0.priority <= .high }
    }

    @ViewBuilder
    private func usageContent(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Primary quota (session/5h)
            if let session = snapshot.sessionQuota {
                UsageBarView(
                    label: ProviderDisplay.primaryUsageLabel(for: provider.id),
                    quota: session,
                    color: providerColor,
                    resetStyle: ProviderDisplay.primaryResetStyle(for: provider.id)
                )
            }

            // Secondary quota (weekly)
            if let weekly = snapshot.weeklyQuota,
               let secondaryLabel = ProviderDisplay.secondaryUsageLabel(for: provider.id) {
                UsageBarView(
                    label: secondaryLabel,
                    quota: weekly,
                    color: providerColor,
                    resetStyle: ProviderDisplay.secondaryResetStyle(for: provider.id)
                )
            }

            // Model-specific quotas
            ForEach(Array(snapshot.modelSpecificQuotas.enumerated()), id: \.offset) { _, modelQuota in
                UsageBarView(
                    label: modelQuota.quotaType.displayName,
                    quota: modelQuota,
                    color: providerColor
                )
            }

            // Cost usage (Claude API / Bedrock)
            if let cost = snapshot.costUsage {
                HStack {
                    Text("Cost")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(cost.formattedCost)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary)
                    if let budget = cost.formattedBudget {
                        Text("/ \(budget)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // One-line insight for critical/high priority
            if let insight = topInsight {
                HStack(spacing: 4) {
                    Image(systemName: insight.symbolName)
                        .font(.system(size: 9))
                    Text(insight.title)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(insightColor(insight.severity))
            }

            // Empty state
            if snapshot.quotas.isEmpty && snapshot.costUsage == nil {
                Text("Quota data unavailable")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func insightColor(_ severity: UsageInsight.Severity) -> Color {
        switch severity {
        case .positive: .green
        case .neutral: .secondary
        case .caution: .orange
        case .urgent: .red
        }
    }
}
