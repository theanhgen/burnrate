import SwiftUI
import WidgetData
import WidgetKit

struct AllProvidersView: View {
    let entry: BurnrateEntry

    @Environment(\.colorScheme) var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var sortedSnapshots: [WidgetProviderSnapshot] {
        entry.snapshots.sorted { lhs, rhs in
            statusPriority(lhs.overallStatus) > statusPriority(rhs.overallStatus)
        }
    }

    var body: some View {
        Group {
            if entry.snapshots.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("burnrate")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()

                        HStack(spacing: 8) {
                            if let newest = entry.snapshots.map(\.capturedAt).max() {
                                HStack(spacing: 2) {
                                    Text(newest, style: .relative)
                                    Text("ago")
                                }
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            }

                            Button(intent: RefreshIntent()) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(sortedSnapshots.prefix(6)) { snapshot in
                            ProviderCell(snapshot: snapshot, colorScheme: colorScheme)
                        }
                    }
                }
                .padding(2)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "burnrate://dashboard"))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open burnrate on Mac\nto sync data")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func statusPriority(_ status: String) -> Int {
        switch status {
        case "depleted": 4
        case "critical": 3
        case "warning": 2
        case "healthy": 1
        default: 0
        }
    }
}

// MARK: - Provider Cell

private struct ProviderCell: View {
    let snapshot: WidgetProviderSnapshot
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: WidgetProviderVisuals.symbolIcon(for: snapshot.providerId))
                .font(.caption2)
                .foregroundStyle(WidgetProviderVisuals.color(for: snapshot.providerId, scheme: colorScheme))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.displayName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(WidgetStatusColors.color(for: snapshot.overallStatus))
                            .frame(width: geo.size.width * barWidth)
                    }
                }
                .frame(height: 4)
            }

            Text("\(Int(snapshot.primaryQuota?.percentRemaining ?? 0))%")
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var barWidth: CGFloat {
        CGFloat(max(0, min(1, (snapshot.primaryQuota?.percentRemaining ?? 0) / 100)))
    }
}
