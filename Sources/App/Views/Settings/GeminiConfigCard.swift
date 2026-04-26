#if MAS_BUILD
import SwiftUI
import Domain
import Infrastructure

/// Gemini provider configuration card for MAS builds.
/// Shows folder access button for ~/.gemini/ credentials.
struct GeminiConfigCard: View {
    let monitor: QuotaMonitor

    @Environment(\.appTheme) private var theme

    @State private var geminiConfigExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $geminiConfigExpanded) {
            Divider()
                .background(theme.glassBorder)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 14) {
                FolderAccessButton(
                    folderID: BookmarkFolderID.gemini,
                    folderPath: "~/.gemini/",
                    providerName: "Gemini",
                    bookmarkManager: SecurityScopedBookmarkManager()
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gemini uses OAuth credentials stored by the Gemini CLI.")
                        .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Text("Run `gemini` in terminal to authenticate, then grant folder access above.")
                        .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Text("If tokens expire, run `gemini` again to refresh them.")
                        .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        } label: {
            geminiConfigHeader
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        geminiConfigExpanded.toggle()
                    }
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.glassBorder, theme.glassBorder.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var geminiConfigHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.26, green: 0.52, blue: 0.96),
                                Color(red: 0.18, green: 0.38, blue: 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Gemini Configuration")
                    .font(.system(size: 14, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Credential folder access")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
    }
}
#endif
