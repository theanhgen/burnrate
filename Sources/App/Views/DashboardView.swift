import SwiftUI
import Domain

/// Main dashboard shown in the menu bar window.
/// Adapted from burnrate's 320px compact design, consuming its domain.
struct DashboardView: View {
    let monitor: QuotaMonitor
    let sessionMonitor: SessionMonitor
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                BurnrateSettingsView(monitor: monitor, onDone: { showSettings = false })
            } else {
                dashboardContent
            }
        }
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ForEach(monitor.sortedEnabledProviders, id: \.id) { provider in
                Button(action: {
                    DetailWindowController.shared.open(
                        monitor: monitor,
                        sessionMonitor: sessionMonitor,
                        provider: provider.id
                    )
                }) {
                    ProviderCardView(provider: provider)
                }
                .buttonStyle(InteractiveButtonStyle(color: ProviderDisplay.color(for: provider.id)))
            }

            if !sessionMonitor.activeSessions.isEmpty || !sessionMonitor.recentSessions.isEmpty {
                Divider()
                SessionListView(monitor: monitor, sessionMonitor: sessionMonitor)
            }
        }
        .padding(16)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("burnrate")
                    .font(.system(size: 16, weight: .bold))
                let sessionCount = sessionMonitor.activeSessions.count
                Text("\(sessionCount) active session\(sessionCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: {
                Task { await monitor.refreshAll() }
            }) {
                if monitor.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(HeaderButtonStyle())
            .foregroundStyle(.secondary)

            Button(action: {
                showSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(HeaderButtonStyle())
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Menu Bar Label

struct BurnrateMenuBarLabel: View {
    let monitor: QuotaMonitor

    var body: some View {
        Label("burnrate", systemImage: "flame")
    }
}
