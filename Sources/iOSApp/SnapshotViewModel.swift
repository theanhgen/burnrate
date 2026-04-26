import CloudSync
import Domain
import Foundation
import WidgetKit

@Observable
@MainActor
final class SnapshotViewModel {
    private let reader: CloudKitSnapshotReader

    var snapshots: [UsageSnapshot] = []
    var isLoading = false
    var errorMessage: String?

    init(reader: CloudKitSnapshotReader = CloudKitSnapshotReader()) {
        self.reader = reader
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshots = try await reader.fetchAll()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "Could not load data. Make sure you're signed into iCloud."
        }
    }

    /// Snapshots sorted by provider name, filtering out empty ones.
    var activeSnapshots: [UsageSnapshot] {
        snapshots
            .filter { !$0.quotas.isEmpty || $0.costUsage != nil }
            .sorted { $0.providerId < $1.providerId }
    }
}
