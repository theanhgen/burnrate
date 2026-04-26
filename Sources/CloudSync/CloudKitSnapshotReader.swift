import Domain
import Foundation

/// iOS-side service that fetches usage snapshots from CloudKit.
public final class CloudKitSnapshotReader: Sendable {
    private let container: CloudSyncContainer

    public init(container: CloudSyncContainer = CloudSyncContainer()) {
        self.container = container
    }

    /// Fetches all provider snapshots from CloudKit.
    public func fetchAll() async throws -> [UsageSnapshot] {
        try await container.fetchAllSnapshots()
    }
}
