import Foundation

/// Tracks MAS onboarding state for folder access grants.
///
/// Determines whether to show the setup assistant on first launch or after
/// access has been lost. Access is considered "lost" only for folders that
/// were previously granted — folders the user skipped never trigger a re-show.
public final class MASOnboardingManager: @unchecked Sendable {

    private let defaults: UserDefaults
    private let bookmarkManager: any BookmarkManaging

    private static let completedKey = "com.burnrate.mas.onboardingComplete"

    /// Folder IDs that require user authorization in the MAS build.
    public static let requiredFolderIDs: [String] = [
        BookmarkFolderID.claude,
        BookmarkFolderID.codex,
        BookmarkFolderID.gemini,
    ]

    public init(
        defaults: UserDefaults = .standard,
        bookmarkManager: any BookmarkManaging
    ) {
        self.defaults = defaults
        self.bookmarkManager = bookmarkManager
    }

    // MARK: - State

    /// Whether the user has completed (or dismissed) onboarding at least once.
    public var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Self.completedKey)
    }

    /// Marks onboarding as completed so it won't auto-show again.
    public func markComplete() {
        defaults.set(true, forKey: Self.completedKey)
    }

    /// Resets onboarding state, causing it to show on the next launch.
    public func reset() {
        defaults.removeObject(forKey: Self.completedKey)
    }

    /// Returns true if any previously-granted folder's bookmark is now stale or missing.
    /// Folders the user never granted are not considered "lost".
    public var hasLostAccess: Bool {
        for folderID in Self.requiredFolderIDs {
            guard bookmarkManager.hasBookmark(for: folderID) else { continue }
            if bookmarkManager.resolveBookmark(for: folderID) == nil { return true }
        }
        return false
    }

    /// Whether the onboarding flow should be shown.
    /// - True on first launch (never completed).
    /// - True if a previously-granted folder's access is now unresolvable.
    /// - False if completed and all granted bookmarks still resolve.
    public var shouldShowOnboarding: Bool {
        if !hasCompletedOnboarding { return true }
        return hasLostAccess
    }

    /// Returns the set of required folder IDs that currently have bookmarks.
    public func grantedFolderIDs() -> Set<String> {
        Set(Self.requiredFolderIDs.filter { bookmarkManager.hasBookmark(for: $0) })
    }
}
