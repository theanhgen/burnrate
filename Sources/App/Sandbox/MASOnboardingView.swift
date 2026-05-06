#if MAS_BUILD
import SwiftUI
import Infrastructure

/// Guided setup sheet for granting folder access in the MAS sandbox build.
///
/// Shown on first launch (or after access is lost) via `MASOnboardingWindowController`.
/// Each provider row reuses `FolderAccessButton` — NSOpenPanel is opened from there,
/// pre-filled to the target directory so users click once, not navigate manually.
struct MASOnboardingView: View {
    let bookmarkManager: any BookmarkManaging
    let onComplete: () -> Void

    private let providerRows: [(id: String, name: String, path: String)] = [
        (id: BookmarkFolderID.claude, name: "Claude", path: "~/.claude"),
        (id: BookmarkFolderID.codex,  name: "Codex",  path: "~/.codex"),
        (id: BookmarkFolderID.gemini, name: "Gemini", path: "~/.gemini"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 20)

            Divider()

            providerSection
                .padding(.vertical, 16)

            Divider()

            footer
                .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 440)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Setup Required")
                    .font(.system(size: 20, weight: .bold))
            }
            Text("burnrate reads AI quota data from credential files on your Mac. Grant folder access once — burnrate never uploads or modifies your credentials.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI Providers")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(providerRows.enumerated()), id: \.element.id) { index, row in
                    FolderAccessButton(
                        folderID: row.id,
                        folderPath: row.path,
                        providerName: row.name,
                        bookmarkManager: bookmarkManager
                    )
                    if index < providerRows.count - 1 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip for Now") {
                onComplete()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
            .help("You can grant access later via Settings → Folder Access")

            Spacer()

            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
}
#endif
