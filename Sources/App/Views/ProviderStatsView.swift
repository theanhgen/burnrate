import SwiftUI
import Domain

/// Shows 7-day aggregate stats for a provider.
/// Adapted from burnrate — uses its daily usage report when available.
struct ProviderStatsView: View {
    let providerId: String
    let monitor: QuotaMonitor

    private var provider: (any AIProvider)? {
        monitor.provider(for: providerId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let report = provider?.snapshot?.dailyUsageReport {
                dailyUsageSection(report)
            }

            snapshotStatsSection
        }
    }

    // MARK: - Daily Usage from burnrate's JSONL analysis

    @ViewBuilder
    private func dailyUsageSection(_ report: DailyUsageReport) -> some View {
        Text("Today's Usage")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            statCard(label: "Cost", value: report.today.formattedCost)
            statCard(label: "Tokens", value: report.today.formattedTokens)
            statCard(label: "Time", value: report.today.formattedWorkingTime)
        }
    }

    // MARK: - Snapshot-based stats

    @ViewBuilder
    private var snapshotStatsSection: some View {
        let snapshots = BurnrateSnapshotStore.shared.query(
            provider: providerId,
            since: Date().addingTimeInterval(-7 * 24 * 3600)
        )

        if !snapshots.isEmpty {
            Text("Stats (7 days)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            let avgSession = snapshots.map(\.session).reduce(0, +) / max(snapshots.count, 1)
            let avgWeekly = snapshots.map(\.weekly).reduce(0, +) / max(snapshots.count, 1)
            let dataPoints = snapshots.count

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                statCard(label: "Avg Session", value: "\(avgSession)%")
                statCard(label: "Avg Weekly", value: "\(avgWeekly)%")
                statCard(label: "Data Points", value: "\(dataPoints)")
            }
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
