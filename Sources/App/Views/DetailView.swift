import SwiftUI
import Domain

/// Full-window detail dashboard with per-provider tabs.
/// Adapted from burnrate's design, consuming its domain.
struct DetailView: View {
    let monitor: QuotaMonitor
    let sessionMonitor: SessionMonitor
    @State private var selectedTab: String  // "all" or provider ID
    @State private var showingSettings = false
    @State private var showAllSessions = false
    @State private var showAllRecent = false

    init(monitor: QuotaMonitor, sessionMonitor: SessionMonitor, initialProvider: String? = nil) {
        self.monitor = monitor
        self.sessionMonitor = sessionMonitor
        _selectedTab = State(initialValue: initialProvider ?? "all")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            HStack(spacing: 6) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        showAllSessions = false
                        showAllRecent = false
                    } label: {
                        Text(tabLabel(tab))
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedTab == tab
                                    ? AnyShapeStyle(tabColor(tab))
                                    : AnyShapeStyle(Color.primary.opacity(0.06))
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                HStack(spacing: 8) {
                    ExportButton(providerId: selectedTab == "all" ? nil : selectedTab, monitor: monitor)

                    Button(action: { Task { await monitor.refreshAll() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == "all" {
                        allProvidersView
                    } else if let provider = monitor.provider(for: selectedTab) {
                        singleProviderView(provider)
                    }

                    if selectedTab == "all" || selectedTab == "claude" {
                        Divider()
                        sessionsSection
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showingSettings) {
            BurnrateSettingsView(monitor: monitor, onDone: { showingSettings = false })
                .frame(width: 400, height: 500)
        }
    }

    private var visibleTabs: [String] {
        var tabs: [String] = ["all"]
        for provider in monitor.sortedEnabledProviders {
            if provider.snapshot != nil {
                tabs.append(provider.id)
            }
        }
        return tabs
    }

    private func tabLabel(_ tab: String) -> String {
        if tab == "all" { return "All" }
        return ProviderDisplay.name(for: tab)
    }

    private func tabColor(_ tab: String) -> Color {
        if tab == "all" { return .gray }
        return ProviderDisplay.color(for: tab)
    }

    // MARK: - All providers combined

    private var allProvidersView: some View {
        VStack(alignment: .leading, spacing: 16) {
            providerSummaryCards
            InsightsView(providerId: nil, monitor: monitor)
            UsageChartView(providerId: nil, monitor: monitor)
        }
    }

    private var providerSummaryCards: some View {
        HStack(spacing: 12) {
            ForEach(monitor.sortedEnabledProviders.filter { $0.snapshot != nil }, id: \.id) { provider in
                let snapshot = provider.snapshot!
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: ProviderDisplay.icon(for: provider.id))
                            .font(.system(size: 10))
                            .foregroundStyle(ProviderDisplay.color(for: provider.id))
                        Text(provider.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                    HStack(spacing: 8) {
                        if let session = snapshot.sessionQuota {
                            VStack(spacing: 1) {
                                Text("\(Int(session.percentUsed))%")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text("Session")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        if let weekly = snapshot.weeklyQuota {
                            VStack(spacing: 1) {
                                Text("\(Int(weekly.percentUsed))%")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text("Weekly")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        if snapshot.sessionQuota == nil, snapshot.weeklyQuota == nil,
                           let best = snapshot.lowestQuota {
                            VStack(spacing: 1) {
                                Text("\(Int(best.percentUsed))%")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text(best.quotaType.displayName)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(ProviderDisplay.color(for: provider.id).opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ProviderDisplay.color(for: provider.id).opacity(0.1), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Single provider

    private func singleProviderView(_ provider: any AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: ProviderDisplay.icon(for: provider.id))
                    .foregroundStyle(ProviderDisplay.color(for: provider.id))
                    .font(.system(size: 16))
                Text(provider.name)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                ConfidenceBadge(confidence: provider.confidence)
            }

            if let snapshot = provider.snapshot {
                usageBars(provider, snapshot: snapshot)

                UsageChartView(providerId: provider.id, monitor: monitor)
                ActivityHeatmapView(providerId: provider.id)
                InsightsView(providerId: provider.id, monitor: monitor)
                ProviderStatsView(providerId: provider.id, monitor: monitor)
            } else {
                Text("No data available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func usageBars(_ provider: any AIProvider, snapshot: UsageSnapshot) -> some View {
        let color = ProviderDisplay.color(for: provider.id)

        if let session = snapshot.sessionQuota {
            UsageBarView(
                label: ProviderDisplay.primaryUsageLabel(for: provider.id),
                quota: session,
                color: color,
                resetStyle: ProviderDisplay.primaryResetStyle(for: provider.id)
            )
        }

        if let weekly = snapshot.weeklyQuota,
           let secondaryLabel = ProviderDisplay.secondaryUsageLabel(for: provider.id) {
            UsageBarView(
                label: secondaryLabel,
                quota: weekly,
                color: color,
                resetStyle: ProviderDisplay.secondaryResetStyle(for: provider.id)
            )
        }

        ForEach(Array(snapshot.modelSpecificQuotas.enumerated()), id: \.offset) { _, modelQuota in
            UsageBarView(
                label: modelQuota.quotaType.displayName,
                quota: modelQuota,
                color: color
            )
        }
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        let limit = 10
        let total = sessionMonitor.activeSessions.count
        let visibleCount = showAllSessions ? total : min(total, limit)
        let sessions = Array(sessionMonitor.activeSessions.prefix(visibleCount))
        let hasMore = total > limit && !showAllSessions

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Sessions (\(total))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if hasMore {
                    Button { showAllSessions = true } label: {
                        Text("Show \(total - limit) more...")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else if showAllSessions && total > limit {
                    Button { showAllSessions = false } label: {
                        Text("Show less")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !sessions.isEmpty {
                ForEach(sessions) { session in
                    ActiveSessionRow(session: session)
                }
            } else {
                Text("No active sessions")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }

            if !sessionMonitor.recentSessions.isEmpty {
                let recentLimit = 3
                let recentTotal = sessionMonitor.recentSessions.count
                let recentHasMore = recentTotal > recentLimit && !showAllRecent

                HStack {
                    Text("Recent (\(recentTotal))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if recentHasMore {
                        Button { showAllRecent = true } label: {
                            Text("Show \(recentTotal - recentLimit) more...")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    } else if showAllRecent && recentTotal > recentLimit {
                        Button { showAllRecent = false } label: {
                            Text("Show less")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)

                let recentVisible = showAllRecent ? recentTotal : min(recentTotal, recentLimit)
                ForEach(sessionMonitor.recentSessions.prefix(recentVisible), id: \.id) { session in
                    RecentSessionRow(session: session)
                }
            }
        }
    }
}
