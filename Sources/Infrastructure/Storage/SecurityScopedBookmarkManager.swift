import Foundation
import Domain
import Mockable

// MARK: - Folder ID Constants

/// Well-known folder identifiers for security-scoped bookmarks.
/// Each corresponds to a credential folder that the user grants access to via NSOpenPanel.
public enum BookmarkFolderID {
    public static let claude = "claude"    // ~/.claude/
    public static let codex = "codex"      // ~/.codex/
    public static let gemini = "gemini"    // ~/.gemini/
    public static let aws = "aws"          // ~/.aws/
}

// MARK: - Protocol

/// Manages security-scoped bookmarks for sandbox-safe file access.
/// In the MAS build, credential loaders use this to read/write files
/// in user-granted folders (e.g., ~/.claude/, ~/.codex/).
// Note: @Mockable removed — withScopedAccess uses non-escaping closures
// that are incompatible with the Mockable macro's generated code.
public protocol BookmarkManaging: Sendable {
    /// Returns true if a bookmark exists for the given folder.
    func hasBookmark(for folderID: String) -> Bool

    /// Resolves a stored bookmark to a URL. Returns nil if no bookmark
    /// exists or the bookmark is stale (folder moved/deleted).
    func resolveBookmark(for folderID: String) -> URL?

    /// Creates and persists a security-scoped bookmark for the given URL.
    func saveBookmark(for folderID: String, url: URL) throws

    /// Removes the stored bookmark for the given folder.
    func deleteBookmark(for folderID: String)

    /// Executes `body` with security-scoped access to the bookmarked folder.
    /// Calls `startAccessingSecurityScopedResource()` before and
    /// `stopAccessingSecurityScopedResource()` after (in defer).
    /// Throws `BookmarkError.noBookmark` if no bookmark exists.
    func withScopedAccess<T: Sendable>(folderID: String, body: @Sendable () throws -> T) throws -> T

    /// Async variant of `withScopedAccess`.
    func withScopedAccess<T: Sendable>(folderID: String, body: @Sendable () async throws -> T) async throws -> T
}

// MARK: - Errors

public enum BookmarkError: Error, Equatable {
    case noBookmark
    case staleBookmark
    case bookmarkCreationFailed(String)
}

// MARK: - Implementation

/// Concrete implementation that persists bookmarks in UserDefaults.
public final class SecurityScopedBookmarkManager: BookmarkManaging, @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()

    private static let keyPrefix = "com.burnrate.bookmark."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - BookmarkManaging

    public func hasBookmark(for folderID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.data(forKey: Self.key(for: folderID)) != nil
    }

    public func resolveBookmark(for folderID: String) -> URL? {
        lock.lock()
        let bookmarkData: Data? = defaults.data(forKey: Self.key(for: folderID))
        lock.unlock()

        guard let data = bookmarkData else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Try to re-save the bookmark with the resolved URL
                AppLog.ui.warning("Bookmark for '\(folderID)' is stale, attempting re-save")
                do {
                    try saveBookmark(for: folderID, url: url)
                } catch {
                    AppLog.ui.error("Failed to re-save stale bookmark for '\(folderID)': \(error.localizedDescription)")
                }
            }

            return url
        } catch {
            AppLog.ui.error("Failed to resolve bookmark for '\(folderID)': \(error.localizedDescription)")
            return nil
        }
    }

    public func saveBookmark(for folderID: String, url: URL) throws {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            lock.lock()
            defaults.set(data, forKey: Self.key(for: folderID))
            lock.unlock()
            AppLog.ui.info("Saved bookmark for '\(folderID)'")
        } catch {
            throw BookmarkError.bookmarkCreationFailed(error.localizedDescription)
        }
    }

    public func deleteBookmark(for folderID: String) {
        lock.lock()
        defaults.removeObject(forKey: Self.key(for: folderID))
        lock.unlock()
        AppLog.ui.info("Deleted bookmark for '\(folderID)'")
    }

    public func withScopedAccess<T: Sendable>(folderID: String, body: @Sendable () throws -> T) throws -> T {
        guard let url = resolveBookmark(for: folderID) else {
            throw BookmarkError.noBookmark
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.staleBookmark
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body()
    }

    public func withScopedAccess<T: Sendable>(folderID: String, body: @Sendable () async throws -> T) async throws -> T {
        guard let url = resolveBookmark(for: folderID) else {
            throw BookmarkError.noBookmark
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.staleBookmark
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try await body()
    }

    // MARK: - Private

    private static func key(for folderID: String) -> String {
        "\(keyPrefix)\(folderID)"
    }
}
