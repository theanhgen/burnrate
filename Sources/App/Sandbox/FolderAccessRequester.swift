#if MAS_BUILD
import AppKit
import Infrastructure

/// Opens an NSOpenPanel pre-filled to a target directory so the user can grant
/// access with one click. Saves the resulting security-scoped bookmark.
@MainActor
public struct FolderAccessRequester {

    /// Requests folder access via NSOpenPanel and saves the bookmark on success.
    ///
    /// - Parameters:
    ///   - directoryURL: The directory to open the panel at (e.g., `~/.claude/`)
    ///   - message: Explanation shown in the panel (e.g., "Grant burnrate access to your Claude credentials")
    ///   - bookmarkManager: The bookmark manager to persist the grant
    ///   - folderID: The folder identifier (e.g., `BookmarkFolderID.claude`)
    /// - Returns: `true` if access was granted and bookmark saved
    @discardableResult
    public static func requestAccess(
        directoryURL: URL,
        message: String,
        bookmarkManager: any BookmarkManaging,
        folderID: String
    ) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.canCreateDirectories = false
        panel.message = message
        panel.prompt = "Grant Access"

        // Pre-fill to the target directory if it exists
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            panel.directoryURL = directoryURL
        } else {
            // Folder doesn't exist yet -- open at home directory
            panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        }

        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return false
        }

        do {
            try bookmarkManager.saveBookmark(for: folderID, url: selectedURL)
            return true
        } catch {
            return false
        }
    }
}
#endif
