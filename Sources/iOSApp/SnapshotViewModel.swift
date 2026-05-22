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
        } catch CloudSyncError.noAccount {
            errorMessage = "Sign into iCloud in Settings to enable sync."
        } catch {
            errorMessage = "Could not load data from iCloud. Check your connection and try again."
        }
    }

    /// Snapshots sorted by provider name, filtering out empty ones.
    var activeSnapshots: [UsageSnapshot] {
        snapshots
            .filter { !$0.quotas.isEmpty || $0.costUsage != nil }
            .sorted { $0.providerId < $1.providerId }
    }
}
