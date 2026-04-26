import Foundation
import SwiftData
import Domain

/// Record of a usage snapshot at a point in time, for charts/heatmap/insights.
@Model
final class UsageSnapshotRecord {
    var ts: TimeInterval
    var provider: String
    var session: Int
    var weekly: Int
    var overage: Int?

    init(ts: TimeInterval, provider: String, session: Int, weekly: Int, overage: Int? = nil) {
        self.ts = ts
        self.provider = provider
        self.session = session
        self.weekly = weekly
        self.overage = overage
    }
}

/// Persists usage snapshots over time for historical charts, heatmaps, and insights.
/// Uses SwiftData for local persistence.
@MainActor
final class BurnrateSnapshotStore {
    static let shared = BurnrateSnapshotStore()

    let container: ModelContainer

    private init() {
        do {
            let schema = Schema([UsageSnapshotRecord.self])
            let config = ModelConfiguration(
                "BurnRateUsageHistory",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize SwiftData ModelContainer: \(error)")
        }
    }

    /// Save current provider states from QuotaMonitor
    func save(from monitor: QuotaMonitor) {
        let now = Date().timeIntervalSince1970
        let context = container.mainContext

        for provider in monitor.enabledProviders {
            guard let snapshot = provider.snapshot else { continue }

            var session = snapshot.sessionQuota.map { Int($0.percentUsed) } ?? 0
            var weekly = snapshot.weeklyQuota.map { Int($0.percentUsed) } ?? 0

            // Fallback: use the most critical quota when session/weekly aren't available
            if session == 0 && weekly == 0, let lowest = snapshot.lowestQuota {
                session = Int(lowest.percentUsed)
            }

            // Only save if there's actual data
            guard session > 0 || weekly > 0 else { continue }

            let record = UsageSnapshotRecord(
                ts: now,
                provider: provider.id,
                session: session,
                weekly: weekly
            )
            context.insert(record)
        }

        try? context.save()
    }

    /// Query snapshots for a provider within a time range
    func query(provider: String, since: Date) -> [UsageSnapshotRecord] {
        let cutoff = since.timeIntervalSince1970
        let providerRaw = provider

        let descriptor = FetchDescriptor<UsageSnapshotRecord>(
            predicate: #Predicate<UsageSnapshotRecord> {
                $0.provider == providerRaw && $0.ts >= cutoff
            },
            sortBy: [SortDescriptor(\.ts)]
        )

        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    /// Query all providers since a date
    func queryAll(since: Date) -> [UsageSnapshotRecord] {
        let cutoff = since.timeIntervalSince1970

        let descriptor = FetchDescriptor<UsageSnapshotRecord>(
            predicate: #Predicate<UsageSnapshotRecord> {
                $0.ts >= cutoff
            },
            sortBy: [SortDescriptor(\.ts)]
        )

        return (try? container.mainContext.fetch(descriptor)) ?? []
    }
}
