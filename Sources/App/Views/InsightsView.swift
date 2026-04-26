import SwiftUI
import Domain

struct InsightsView: View {
    let providerId: String?
    let monitor: QuotaMonitor
    @State private var insights: [UsageInsight] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !insights.isEmpty {
                Text("Insights")
                    .font(.system(size: 13, weight: .semibold))

                if let headline = insights.first {
                    InsightCardView(insight: headline, isHeadline: true)
                }

                if insights.count > 1 {
                    let columns = [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                        ForEach(insights.dropFirst(), id: \.id) { insight in
                            CompactInsightCell(insight: insight)
                        }
                    }
                }
            }
        }
        .task(id: providerId) {
            loadInsights()
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadInsights() {
        let store = BurnrateSnapshotStore.shared
        let now = Date()

        // Current period: last 7 days
        let currentSnapshots = querySnapshots(store: store, since: now.addingTimeInterval(-7 * 24 * 3600))
        let currentSummary = SnapshotSummary.from(snapshots: currentSnapshots)

        // Previous period: 7-14 days ago
        let allTwoWeeks = querySnapshots(store: store, since: now.addingTimeInterval(-14 * 24 * 3600))
        let previousOnly = allTwoWeeks.filter { $0.ts < now.addingTimeInterval(-7 * 24 * 3600).timeIntervalSince1970 }
        let previousSummary = SnapshotSummary.from(snapshots: previousOnly)

        // Live quotas
        let liveQuotas: [UsageQuota]
        if let pid = providerId, let provider = monitor.provider(for: pid) {
            liveQuotas = provider.snapshot?.quotas ?? []
        } else {
            // All tab: collect quotas from all enabled providers
            liveQuotas = monitor.sortedEnabledProviders.flatMap { $0.snapshot?.quotas ?? [] }
        }

        // Forecast (session from last 6h, or weekly from last 48h)
        let forecast = buildForecast(store: store, now: now)

        // Daily report (Claude only)
        let dailyReport: DailyUsageReport?
        if let pid = providerId, let provider = monitor.provider(for: pid) {
            dailyReport = provider.snapshot?.dailyUsageReport
        } else {
            dailyReport = nil
        }

        let context = InsightContext(
            providerId: providerId,
            liveQuotas: liveQuotas,
            currentPeriod: currentSummary,
            previousPeriod: previousSummary,
            forecast: forecast,
            dailyReport: dailyReport,
            now: now
        )

        insights = InsightEngine().evaluate(context: context)
    }

    private func querySnapshots(
        store: BurnrateSnapshotStore,
        since: Date
    ) -> [(ts: TimeInterval, session: Int, weekly: Int)] {
        let records: [UsageSnapshotRecord]
        if let pid = providerId {
            records = store.query(provider: pid, since: since)
        } else {
            records = store.queryAll(since: since)
        }
        return records.map { (ts: $0.ts, session: $0.session, weekly: $0.weekly) }
    }

    @MainActor
    private func buildForecast(store: BurnrateSnapshotStore, now: Date) -> QuotaForecast? {
        guard let pid = providerId else { return nil }

        // Try weekly forecast (48h window) first, fall back to session (6h)
        let weeklySnaps = store.query(provider: pid, since: now.addingTimeInterval(-48 * 3600))
        if !weeklySnaps.isEmpty {
            let points = weeklySnaps.map { (timestamp: Date(timeIntervalSince1970: $0.ts), percentUsed: Double($0.weekly)) }
            if let forecast = QuotaForecast.from(points: points, now: now) {
                return forecast
            }
        }

        let sessionSnaps = store.query(provider: pid, since: now.addingTimeInterval(-6 * 3600))
        if !sessionSnaps.isEmpty {
            let points = sessionSnaps.map { (timestamp: Date(timeIntervalSince1970: $0.ts), percentUsed: Double($0.session)) }
            return QuotaForecast.from(points: points, now: now)
        }

        return nil
    }
}
