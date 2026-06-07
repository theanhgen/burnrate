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

    private var lastSavedValues: [String: (session: Int, weekly: Int)] = [:]
    private var lastPruneDate: Date = .distantPast

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

    /// Save current provider states from QuotaMonitor.
    /// Skips insert when values are unchanged since the previous save.
    /// Prunes records older than 30 days once per day.
    func save(from monitor: QuotaMonitor) {
        let now = Date().timeIntervalSince1970
        let context = container.mainContext

        if Date().timeIntervalSince(lastPruneDate) > 86400 {
            lastPruneDate = Date()
            pruneOldRecords(before: now - 30 * 24 * 3600, context: context)
        }

        var didInsert = false
        for provider in monitor.enabledProviders {
            guard let snapshot = provider.snapshot else { continue }

            var session = snapshot.sessionQuota.map { Int($0.percentUsed) } ?? 0
            var weekly = snapshot.weeklyQuota.map { Int($0.percentUsed) } ?? 0

            // Fallback: use the most critical quota when session/weekly aren't available
            if session == 0 && weekly == 0, let lowest = snapshot.lowestQuota {
                session = Int(lowest.percentUsed)
            }

            guard session > 0 || weekly > 0 else { continue }

            // Skip insert if nothing changed since last save
            if let last = lastSavedValues[provider.id],
               last.session == session, last.weekly == weekly {
                continue
            }
            lastSavedValues[provider.id] = (session: session, weekly: weekly)

            context.insert(UsageSnapshotRecord(
                ts: now,
                provider: provider.id,
                session: session,
                weekly: weekly
            ))
            didInsert = true
        }

        if didInsert {
            try? context.save()
        }
    }

    private func pruneOldRecords(before cutoff: TimeInterval, context: ModelContext) {
        let descriptor = FetchDescriptor<UsageSnapshotRecord>(
            predicate: #Predicate<UsageSnapshotRecord> { $0.ts < cutoff }
        )
        guard let old = try? context.fetch(descriptor), !old.isEmpty else { return }
        old.forEach { context.delete($0) }
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
