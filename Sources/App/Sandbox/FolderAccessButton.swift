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

    @State private var hasAccess: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: hasAccess ? "checkmark.shield.fill" : "folder.badge.questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(hasAccess ? Color.green : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)

                    Text(folderPath)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if hasAccess {
                    Button("Revoke") {
                        bookmarkManager.deleteBookmark(for: folderID)
                        hasAccess = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
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
                    .font(.system(size: 10, weight: .semibold))
                }
            }

            Text(hasAccess
                 ? "Access granted — burnrate can read your \(providerName) credentials."
                 : "burnrate needs access to read your \(providerName) credentials.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(hasAccess ? Color.secondary : Color(nsColor: .systemOrange))
        }
        .padding(.vertical, 6)
        .onAppear {
            hasAccess = bookmarkManager.hasBookmark(for: folderID)
        }
    }
}
#endif
