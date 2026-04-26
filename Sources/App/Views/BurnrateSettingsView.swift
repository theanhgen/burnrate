import SwiftUI
import Domain

/// Settings view adapted from burnrate's design.
/// Provides provider toggles, display options, and theme selection.
struct BurnrateSettingsView: View {
    let monitor: QuotaMonitor
    var onDone: (() -> Void)?

    @State private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    if let onDone {
                        Button("Done") { onDone() }
                            .foregroundStyle(.blue)
                            .font(.system(size: 12))
                    }
                }

                // Providers
                VStack(alignment: .leading, spacing: 2) {
                    Text("Providers")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(monitor.allProviders, id: \.id) { provider in
                        providerToggle(provider: provider)
                    }
                }

                Divider()

                // Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    // Theme
                    HStack {
                        Text("Theme")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $settings.themeMode) {
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                            Text("System").tag("system")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    // Daily usage cards
                    Toggle(isOn: Binding(
                        get: { settings.showDailyUsageCards },
                        set: { settings.showDailyUsageCards = $0 }
                    )) {
                        Text("Daily Usage Cards")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    // Burn rate warnings
                    Toggle(isOn: Binding(
                        get: { settings.burnrateWarningEnabled },
                        set: { settings.burnrateWarningEnabled = $0 }
                    )) {
                        Text("burnrate Warnings")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Divider()

                // Background sync
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: Binding(
                        get: { settings.backgroundSyncEnabled },
                        set: { settings.backgroundSyncEnabled = $0 }
                    )) {
                        Text("Background Sync")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Text("Automatically refresh usage data in the background.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text("Auto-detects CLI auth tokens.\nNo API keys or manual setup needed.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .frame(width: 320, height: 480)
    }

    private func providerToggle(provider: any AIProvider) -> some View {
        let color = ProviderDisplay.color(for: provider.id)
        let icon = ProviderDisplay.icon(for: provider.id)

        return Toggle(isOn: Binding(
            get: { provider.isEnabled },
            set: { monitor.setProviderEnabled(provider.id, enabled: $0) }
        )) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(provider.name)
                    .font(.system(size: 12))
                Spacer()
                Text(providerStatus(provider))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.vertical, 4)
    }

    private func providerStatus(_ provider: any AIProvider) -> String {
        if provider.isSyncing { return "Syncing..." }
        if provider.snapshot != nil { return "Connected" }
        if provider.lastError != nil { return "Error" }
        return "Not connected"
    }
}
