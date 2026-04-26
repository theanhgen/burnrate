import Domain
import Foundation

/// Mac-side service that pushes usage snapshots to CloudKit after each refresh cycle.
public final class CloudKitSnapshotWriter: Sendable {
    private let container: CloudSyncContainer

    public init(container: CloudSyncContainer = CloudSyncContainer()) {
        self.container = container
    }

    /// Publishes snapshots to CloudKit. Best-effort — callers should catch and log errors.
    public func publish(_ snapshots: [UsageSnapshot]) async throws {
        try await container.saveSnapshots(snapshots)
    }
}
