import SwiftUI
import Domain

// MARK: - Phase Color Extension

extension ClaudeSession.Phase {
    /// Color for the session indicator dot, using the provider's brand color for active states.
    func color(providerColor: Color) -> Color {
        switch self {
        case .active, .subagentsWorking: return providerColor
        case .stopped: return .orange
        case .ended: return .gray
        }
    }
}

// MARK: - Session List (dashboard preview — max 5 active)

struct SessionListView: View {
    let monitor: QuotaMonitor
    let sessionMonitor: SessionMonitor
    private let maxVisible = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Active Sessions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if !sessionMonitor.activeSessions.isEmpty {
                ForEach(sessionMonitor.activeSessions.prefix(maxVisible)) { session in
                    ActiveSessionRow(session: session)
                }

                if sessionMonitor.activeSessions.count > maxVisible {
                    Button {
                        DetailWindowController.shared.open(
                            monitor: monitor,
                            sessionMonitor: sessionMonitor,
                            provider: "claude"
                        )
                    } label: {
                        let remaining = sessionMonitor.activeSessions.count - maxVisible
                        Text("Show \(remaining) more...")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            } else if sessionMonitor.recentSessions.isEmpty {
                Text("No active sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }

            // Show recent sessions (last 3)
            ForEach(sessionMonitor.recentSessions.prefix(3), id: \.id) { session in
                RecentSessionRow(session: session)
            }
        }
    }
}

// MARK: - Active Session Row

struct ActiveSessionRow: View {
    let session: ClaudeSession
    private let providerColor = ProviderDisplay.color(for: "claude")

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(session.phase.color(providerColor: providerColor))
                .frame(width: 8, height: 8)

            Text("Claude")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize()

            Text(folderName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if session.completedTaskCount > 0 {
                    Text("\(session.completedTaskCount) tasks")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }

                Text(session.durationDescription)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
    }

    private var folderName: String {
        let cwd = session.cwd
        return (cwd as NSString).lastPathComponent
    }

}

// MARK: - Recent Session Row

struct RecentSessionRow: View {
    let session: ClaudeSession

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 6, height: 6)

            Text(folderName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .fixedSize()

            if let name = session.name {
                Text(name)
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            Text(session.durationDescription)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    private var folderName: String {
        (session.cwd as NSString).lastPathComponent
    }
}
