import Foundation

/// Errors that can occur during CloudKit sync operations.
public enum CloudSyncError: Error, Sendable {
    /// The CKRecord is missing required fields or has invalid data.
    case invalidRecord
    /// The CloudKit zone could not be created.
    case zoneCreationFailed(underlying: Error)
    /// A CloudKit save operation failed.
    case saveFailed(underlying: Error)
    /// A CloudKit fetch operation failed.
    case fetchFailed(underlying: Error)
    /// No iCloud account is signed in.
    case noAccount
}
