#if MAS_BUILD
import SwiftUI
import Infrastructure

/// A reusable button that manages folder access grants for sandboxed MAS builds.
/// Shows "Grant Access" when no bookmark exists, or "Access Granted" with a revoke option.
struct FolderAccessButton: View {
    let folderID: String
    let folderPath: String
    let providerName: String
    let bookmarkManager: any BookmarkManaging

    @Environment(\.appTheme) private var theme
    @State private var hasAccess: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: hasAccess ? "checkmark.shield.fill" : "folder.badge.questionmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hasAccess ? .green : theme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Credential Folder Access")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text(folderPath)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if hasAccess {
                    Button("Revoke") {
                        bookmarkManager.deleteBookmark(for: folderID)
                        hasAccess = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                } else {
                    Button("Grant Access") {
                        let targetURL = URL(fileURLWithPath: NSHomeDirectory())
                            .appendingPathComponent(folderPath.replacingOccurrences(of: "~/", with: ""))
                        let granted = FolderAccessRequester.requestAccess(
                            directoryURL: targetURL,
                            message: "Grant burnrate access to your \(providerName) credentials",
                            bookmarkManager: bookmarkManager,
                            folderID: folderID
                        )
                        hasAccess = granted
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                }
            }

            if !hasAccess {
                Text("burnrate needs access to read your \(providerName) credentials.")
                    .font(.system(size: 10, weight: .regular, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            hasAccess = bookmarkManager.hasBookmark(for: folderID)
        }
    }
}
#endif
