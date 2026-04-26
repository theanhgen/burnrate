import CloudSync
import Domain
import Foundation
import WidgetData
import WidgetKit

struct BurnrateEntry: TimelineEntry {
    let date: Date
    let snapshots: [WidgetProviderSnapshot]
    let selectedProviderId: String?
    let isPlaceholder: Bool

    static let placeholder = BurnrateEntry(
        date: Date(),
        snapshots: [
            WidgetProviderSnapshot(
                providerId: "claude",
                displayName: "Claude",
                capturedAt: Date(),
                tierBadge: "MAX",
                primaryQuota: WidgetQuota(
                    label: "Session",
                    percentRemaining: 72,
                    status: "healthy",
                    resetDescription: "Resets in 3h 15m"
                ),
                secondaryQuota: WidgetQuota(
                    label: "Weekly",
                    percentRemaining: 45,
                    status: "warning",
                    resetDescription: "Resets in 4d 2h"
                ),
                cost: nil,
                overallStatus: "warning"
            ),
        ],
        selectedProviderId: "claude",
        isPlaceholder: true
    )
}

// MARK: - Snapshot Fetching

private enum SnapshotFetcher {
    static func fetch() async -> [WidgetProviderSnapshot] {
        #if os(macOS)
        // macOS: read from shared file written by main app
        return WidgetDataStore().read()
        #else
        // iOS: read from CloudKit (synced by macOS app)
        do {
            let reader = CloudKitSnapshotReader()
            let domainSnapshots = try await reader.fetchAll()
            return domainSnapshots
                .filter { !$0.quotas.isEmpty || $0.costUsage != nil }
                .map { WidgetProviderSnapshot(from: $0) }
        } catch {
            return []
        }
        #endif
    }
}

// MARK: - Configurable Provider (Status Ring)

struct BurnrateTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = BurnrateEntry
    typealias Intent = SelectProviderIntent

    func placeholder(in _: Context) -> BurnrateEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectProviderIntent, in _: Context) async -> BurnrateEntry {
        let snapshots = await SnapshotFetcher.fetch()
        return BurnrateEntry(
            date: Date(),
            snapshots: snapshots,
            selectedProviderId: configuration.provider?.id,
            isPlaceholder: false
        )
    }

    func timeline(
        for configuration: SelectProviderIntent,
        in _: Context
    ) async -> Timeline<BurnrateEntry> {
        let snapshots = await SnapshotFetcher.fetch()
        let entry = BurnrateEntry(
            date: Date(),
            snapshots: snapshots,
            selectedProviderId: configuration.provider?.id,
            isPlaceholder: false
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Static All Providers

struct AllProvidersTimelineProvider: TimelineProvider {
    typealias Entry = BurnrateEntry

    func placeholder(in _: Context) -> BurnrateEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (BurnrateEntry) -> Void) {
        Task {
            let snapshots = await SnapshotFetcher.fetch()
            completion(BurnrateEntry(
                date: Date(),
                snapshots: snapshots,
                selectedProviderId: nil,
                isPlaceholder: false
            ))
        }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<BurnrateEntry>) -> Void) {
        Task {
            let snapshots = await SnapshotFetcher.fetch()
            let entry = BurnrateEntry(
                date: Date(),
                snapshots: snapshots,
                selectedProviderId: nil,
                isPlaceholder: false
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}
