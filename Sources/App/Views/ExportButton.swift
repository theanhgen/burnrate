import SwiftUI
import AppKit
import Domain

/// Toolbar button that renders a visual share card with preview before sharing.
struct ExportButton: View {
    let providerId: String?
    let monitor: QuotaMonitor

    @State private var isHovered = false
    @State private var shareData: ShareSnapshot?

    var body: some View {
        Button(action: prepareShare) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .help("Share usage snapshot")
        .sheet(item: $shareData) { data in
            SharePreviewSheet(snapshot: data, onDismiss: { shareData = nil })
        }
    }

    @MainActor
    private func prepareShare() {
        let providers = resolveProviders()
        guard !providers.isEmpty else { return }

        let store = BurnrateSnapshotStore.shared
        let since = Date().addingTimeInterval(-30 * 24 * 3600)

        // Load heatmap data (30 days)
        let heatmapCounts = loadHeatmapCounts(store: store, since: since)

        // Load insights (30 days)
        let insights = loadInsights(store: store, since: since)

        shareData = ShareSnapshot(
            providers: providers,
            providerId: providerId,
            heatmap: heatmapCounts,
            insights: insights
        )
    }

    private func resolveProviders() -> [ShareProviderData] {
        if let pid = providerId, let provider = monitor.provider(for: pid) {
            return [ShareProviderData(from: provider)]
        }
        return monitor.sortedEnabledProviders
            .filter { $0.snapshot != nil }
            .map { ShareProviderData(from: $0) }
    }

    @MainActor
    private func loadHeatmapCounts(store: BurnrateSnapshotStore, since: Date) -> [String: Int] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let records: [UsageSnapshotRecord]
        if let pid = providerId {
            records = store.query(provider: pid, since: since)
        } else {
            records = store.queryAll(since: since)
        }

        var counts: [String: Int] = [:]
        for record in records {
            let key = formatter.string(from: Date(timeIntervalSince1970: record.ts))
            counts[key, default: 0] = max(counts[key, default: 0], 1)
        }
        return counts
    }

    @MainActor
    private func loadInsights(store: BurnrateSnapshotStore, since: Date) -> ShareInsights {
        let snapshots: [UsageSnapshotRecord]
        if let pid = providerId {
            snapshots = store.query(provider: pid, since: since)
        } else {
            snapshots = store.queryAll(since: since)
        }

        guard !snapshots.isEmpty else {
            return ShareInsights(avgSession: 0, avgWeekly: 0, peak: 0, activeDays: 0)
        }

        let avgSession = snapshots.map(\.session).reduce(0, +) / snapshots.count
        let avgWeekly = snapshots.map(\.weekly).reduce(0, +) / snapshots.count
        let peak = snapshots.map(\.session).max() ?? 0

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let activeDays = Set(
            snapshots.map { formatter.string(from: Date(timeIntervalSince1970: $0.ts)) }
        ).count

        return ShareInsights(
            avgSession: avgSession,
            avgWeekly: avgWeekly,
            peak: peak,
            activeDays: activeDays
        )
    }
}

// MARK: - Data Models

struct ShareSnapshot: Identifiable {
    let id = UUID()
    let providers: [ShareProviderData]
    let providerId: String?
    let heatmap: [String: Int]
    let insights: ShareInsights
}

struct ShareInsights {
    let avgSession: Int
    let avgWeekly: Int
    let peak: Int
    let activeDays: Int
}

struct ShareProviderData: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let sessionPercent: Int?
    let weeklyPercent: Int?
    let sessionResetText: String?
    let weeklyResetText: String?
    let tier: String?
    let domainSnapshot: UsageSnapshot?

    init(from provider: any AIProvider) {
        self.id = provider.id
        self.name = provider.name
        self.icon = ProviderDisplay.icon(for: provider.id)
        self.color = ProviderDisplay.color(for: provider.id)
        self.sessionPercent = provider.snapshot?.sessionQuota.map { Int($0.percentUsed) }
        self.weeklyPercent = provider.snapshot?.weeklyQuota.map { Int($0.percentUsed) }
        self.sessionResetText = provider.snapshot?.sessionQuota?.resetText
        self.weeklyResetText = provider.snapshot?.weeklyQuota?.resetText
        self.tier = provider.snapshot?.accountTier?.displayName
        self.domainSnapshot = provider.snapshot
    }
}

// MARK: - Share Mode

private enum ShareMode: String, CaseIterable {
    case image = "Image"
    case data = "Data"
}

// MARK: - Preview Sheet

private struct SharePreviewSheet: View {
    let snapshot: ShareSnapshot
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var shareMode: ShareMode = .image
    @State private var exportFormat: ExportFormat = .markdown
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            // Header with mode picker
            HStack {
                Text("Share")
                    .font(.system(size: 14, weight: .semibold))

                Picker("", selection: $shareMode) {
                    ForEach(ShareMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            switch shareMode {
            case .image:
                imageContent
            case .data:
                dataContent
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    // MARK: - Image Mode

    private var imageContent: some View {
        VStack(spacing: 12) {
            ShareCardView(snapshot: snapshot, colorScheme: colorScheme)
                .scaleEffect(0.85, anchor: .top)
                .padding(.horizontal, 10)

            HStack(spacing: 12) {
                Button(action: copyImageToClipboard) {
                    Label("Copy Image", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: openShareSheet) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Data Mode

    private var dataContent: some View {
        VStack(spacing: 12) {
            // Format picker
            Picker("Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { fmt in
                    Text(fmt.rawValue).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // Preview
            ScrollView {
                Text(formattedText)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(width: 420, height: 280)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: copyDataToClipboard) {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: saveToFile) {
                    Label("Save...", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Data

    private var exportableSnapshot: ExportableSnapshot {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let inputs = snapshot.providers.map { p in
            ProviderExportInput(id: p.id, name: p.name, snapshot: p.domainSnapshot)
        }
        return ExportableSnapshotBuilder.build(providers: inputs, appVersion: version)
    }

    private var formattedText: String {
        SnapshotFormatter.format(exportableSnapshot, as: exportFormat)
    }

    // MARK: - Image Actions

    @MainActor
    private func renderImage() -> NSImage? {
        let card = ShareCardView(snapshot: snapshot, colorScheme: colorScheme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 4.0
        return renderer.nsImage
    }

    @MainActor
    private func copyImageToClipboard() {
        guard let image = renderImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        onDismiss()
    }

    @MainActor
    private func openShareSheet() {
        guard let image = renderImage() else { return }
        onDismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let picker = NSSharingServicePicker(items: [image])
            if let contentView = NSApp.keyWindow?.contentView ?? NSApp.mainWindow?.contentView {
                picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
            }
        }
    }

    // MARK: - Data Actions

    @MainActor
    private func copyDataToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    @MainActor
    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "burnrate-export.\(exportFormat.fileExtension)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try formattedText.write(to: url, atomically: true, encoding: .utf8)
            onDismiss()
        } catch {
            // File write failed — the NSSavePanel already handles most errors
        }
    }
}

// MARK: - Share Card View

private struct ShareCardView: View {
    let snapshot: ShareSnapshot
    var colorScheme: ColorScheme = .dark

    private var providers: [ShareProviderData] { snapshot.providers }
    private var isSingleProvider: Bool { snapshot.providerId != nil && providers.count == 1 }

    // MARK: - Adaptive Colors
    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(white: 0.1) }
    private var textSecondary: Color { isDark ? .white.opacity(0.5) : .black.opacity(0.55) }
    private var textTertiary: Color { isDark ? .white.opacity(0.35) : .black.opacity(0.4) }
    private var surfaceFill: Color { isDark ? .white.opacity(0.06) : .black.opacity(0.04) }
    private var borderStroke: Color { isDark ? .white.opacity(0.08) : .black.opacity(0.08) }
    private var shadowColor: Color { isDark ? .black.opacity(0.4) : .black.opacity(0.12) }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' HH:mm"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            VStack(spacing: 16) {
                // Provider content
                if isSingleProvider, let provider = providers.first {
                    singleProviderContent(provider)
                } else {
                    multiProviderContent
                }

                // Insights row
                insightsSection

                // Heatmap
                heatmapSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            footerSection
        }
        .frame(width: isSingleProvider ? 400 : 440)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: isDark
                            ? [.white.opacity(0.25), .white.opacity(0.05)]
                            : [.black.opacity(0.08), .black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: shadowColor, radius: isDark ? 30 : 20, y: isDark ? 15 : 8)
        .padding(20)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("burnrate")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dateString)
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
                Text("Last 30 days")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(textTertiary.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Single Provider

    private func singleProviderContent(_ provider: ShareProviderData) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(provider.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: provider.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(provider.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                    if let tier = provider.tier {
                        Text(tier)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(textSecondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 20) {
                if let session = provider.sessionPercent {
                    gaugeView(
                        label: "Session",
                        percent: session,
                        color: provider.color,
                        resetText: provider.sessionResetText
                    )
                }
                if let weekly = provider.weeklyPercent {
                    gaugeView(
                        label: "Weekly",
                        percent: weekly,
                        color: provider.color.opacity(0.7),
                        resetText: provider.weeklyResetText
                    )
                }
            }

            if let session = provider.sessionPercent {
                usageBar(percent: session, color: provider.color)
            }
        }
    }

    // MARK: - Multi Provider

    private var multiProviderContent: some View {
        VStack(spacing: 8) {
            ForEach(providers) { provider in
                providerRow(provider)
            }
        }
    }

    private func providerRow(_ provider: ShareProviderData) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(provider.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: provider.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(provider.color)
            }

            Text(provider.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
                .frame(width: 100, alignment: .leading)

            if let session = provider.sessionPercent {
                miniBar(percent: session, color: provider.color)

                Text("\(session)%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor(for: session))
                    .frame(width: 42, alignment: .trailing)
            } else {
                Spacer()
                Text("--")
                    .font(.system(size: 13))
                    .foregroundStyle(textTertiary)
                    .frame(width: 42, alignment: .trailing)
            }

            if let weekly = provider.weeklyPercent {
                Text("\(weekly)%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(textSecondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(surfaceFill)
        )
    }

    // MARK: - Insights

    private var insightsSection: some View {
        HStack(spacing: 0) {
            insightPill(icon: "chart.bar.fill", label: "Avg Session", value: "\(snapshot.insights.avgSession)%")
            insightDivider
            insightPill(icon: "calendar", label: "Avg Weekly", value: "\(snapshot.insights.avgWeekly)%")
            insightDivider
            insightPill(icon: "arrow.up.right", label: "Peak", value: "\(snapshot.insights.peak)%")
            insightDivider
            insightPill(icon: "flame", label: "Active Days", value: "\(snapshot.insights.activeDays)/30")
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderStroke, lineWidth: 1)
                )
        )
    }

    private var insightDivider: some View {
        Rectangle()
            .fill(borderStroke)
            .frame(width: 1, height: 30)
    }

    private func insightPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 7))
                    .foregroundStyle(textTertiary)
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(textTertiary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Activity")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textSecondary)

            let grid = buildHeatmapGrid()
            HStack(alignment: .top, spacing: 0) {
                // Day labels
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(["", "M", "", "W", "", "F", ""], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 7))
                            .foregroundStyle(textTertiary.opacity(0.7))
                            .frame(width: 14, height: 10, alignment: .trailing)
                    }
                }
                .padding(.trailing, 3)

                // Grid
                HStack(spacing: 2) {
                    ForEach(0..<grid.count, id: \.self) { weekIdx in
                        VStack(spacing: 2) {
                            ForEach(0..<7, id: \.self) { dayIdx in
                                if weekIdx < grid.count && dayIdx < grid[weekIdx].count {
                                    let cell = grid[weekIdx][dayIdx]
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(heatmapColor(count: cell.count, isFuture: cell.isFuture))
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.system(size: 7))
                    .foregroundStyle(textTertiary)
                ForEach([0.08, 0.2, 0.4, 0.6, 0.9], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(heatmapBaseColor.opacity(opacity))
                        .frame(width: 8, height: 8)
                }
                Text("More")
                    .font(.system(size: 7))
                    .foregroundStyle(textTertiary)
            }
        }
    }

    // MARK: - Heatmap Helpers

    private struct HeatmapCell {
        let count: Int
        let isFuture: Bool
    }

    private func buildHeatmapGrid() -> [[HeatmapCell]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = (calendar.component(.weekday, from: today) + 5) % 7
        let weeks = 5 // ~30 days

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var grid: [[HeatmapCell]] = []
        for week in 0..<weeks {
            var weekCells: [HeatmapCell] = []
            for day in 0..<7 {
                let gridStartOffset = (weeks - 1) * 7 + todayWeekday
                let cellOffset = gridStartOffset - (week * 7 + day)

                if cellOffset < 0 {
                    weekCells.append(HeatmapCell(count: 0, isFuture: true))
                } else {
                    let date = calendar.date(byAdding: .day, value: -cellOffset, to: today)!
                    let dateStr = formatter.string(from: date)
                    let count = snapshot.heatmap[dateStr] ?? 0
                    weekCells.append(HeatmapCell(count: count, isFuture: false))
                }
            }
            grid.append(weekCells)
        }
        return grid
    }

    private func heatmapColor(count: Int, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        if count == 0 { return heatmapBaseColor.opacity(0.08) }

        let maxCount = max(snapshot.heatmap.values.max() ?? 1, 1)
        let intensity = min(Double(count) / Double(maxCount), 1.0)

        if intensity > 0.75 { return heatmapBaseColor.opacity(0.9) }
        if intensity > 0.5 { return heatmapBaseColor.opacity(0.6) }
        if intensity > 0.25 { return heatmapBaseColor.opacity(0.4) }
        return heatmapBaseColor.opacity(0.2)
    }

    private var heatmapBaseColor: Color {
        if snapshot.providerId != nil, let provider = providers.first {
            return provider.color
        }
        return .green
    }

    // MARK: - Components

    private func gaugeView(label: String, percent: Int, color: Color, resetText: String?) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(min(percent, 100)) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [color, color.opacity(0.6)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 90, height: 90)

                VStack(spacing: 0) {
                    Text("\(percent)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(textPrimary)
                    Text("%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textSecondary)
                }
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.85))

            if let reset = resetText {
                Text(reset)
                    .font(.system(size: 9))
                    .foregroundStyle(textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func usageBar(percent: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(surfaceFill)
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(min(percent, 100)) / 100)
                    .shadow(color: color.opacity(0.5), radius: 6)
            }
        }
        .frame(height: 6)
    }

    private func miniBar(percent: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(surfaceFill)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(min(percent, 100)) / 100)
            }
        }
        .frame(height: 5)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("Tracked with burnrate for macOS")
                .font(.system(size: 10))
                .foregroundStyle(textTertiary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(providers.prefix(8)) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(surfaceFill.opacity(0.5))
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.06, blue: 0.16),
                        Color(red: 0.12, green: 0.08, blue: 0.22),
                        Color(red: 0.10, green: 0.06, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.97, blue: 0.98),
                        Color(red: 0.94, green: 0.94, blue: 0.96),
                        Color(red: 0.96, green: 0.95, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if let first = providers.first {
                RadialGradient(
                    colors: [first.color.opacity(isDark ? 0.15 : 0.08), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
            }

            if providers.count > 1, let second = providers.dropFirst().first {
                RadialGradient(
                    colors: [second.color.opacity(isDark ? 0.08 : 0.05), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 250
                )
            }
        }
    }

    private func statusColor(for percent: Int) -> Color {
        switch percent {
        case 0..<50: textPrimary
        case 50..<75: .orange
        case 75..<90: Color(red: 1.0, green: 0.55, blue: 0.0)
        default: .red
        }
    }
}
