import SwiftUI
import WidgetData
import WidgetKit

struct StatusRingView: View {
    let entry: BurnrateEntry

    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    private var snapshot: WidgetProviderSnapshot? {
        if let selectedId = entry.selectedProviderId {
            return entry.snapshots.first { $0.providerId == selectedId }
        }
        // Fall back to worst-status provider
        return entry.snapshots.sorted(by: { statusPriority($0.overallStatus) > statusPriority($1.overallStatus) }).first
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "burnrate://provider/\(snapshot?.providerId ?? "all")"))
    }

    // MARK: - systemSmall

    private var smallView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                if let snapshot {
                    ZStack {
                        // Background ring track
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                            .frame(width: 72, height: 72)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: ringProgress(snapshot))
                            .stroke(
                                WidgetStatusColors.color(for: snapshot.overallStatus),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 72, height: 72)
                            .widgetAccentable()

                        // Provider icon + percentage
                        VStack(spacing: 1) {
                            Image(systemName: WidgetProviderVisuals.symbolIcon(for: snapshot.providerId))
                                .font(.system(size: 14))
                                .foregroundStyle(WidgetProviderVisuals.color(for: snapshot.providerId, scheme: colorScheme))

                            Text("\(Int(snapshot.primaryQuota?.percentRemaining ?? 0))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }

                    Text(snapshot.displayName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    if let resetDesc = snapshot.primaryQuota?.resetDescription {
                        Text(resetDesc)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 2) {
                            Text(snapshot.capturedAt, style: .relative)
                            Text("ago")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.top, 4)

            if snapshot != nil {
                Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - systemMedium

    private var mediumView: some View {
        HStack(spacing: 16) {
            if let snapshot {
                // Left side: Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: ringProgress(snapshot))
                        .stroke(
                            WidgetStatusColors.color(for: snapshot.overallStatus),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                        .widgetAccentable()

                    VStack(spacing: 2) {
                        Image(systemName: WidgetProviderVisuals.symbolIcon(for: snapshot.providerId))
                            .font(.title2)
                            .foregroundStyle(WidgetProviderVisuals.color(for: snapshot.providerId, scheme: colorScheme))

                        Text("\(Int(snapshot.primaryQuota?.percentRemaining ?? 0))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                // Right side: Quota details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(snapshot.displayName)
                                .font(.headline)
                            if let newest = entry.snapshots.map(\.capturedAt).max() {
                                HStack(spacing: 2) {
                                    Text(newest, style: .relative)
                                    Text("ago")
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Button(intent: RefreshIntent()) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Circle().fill(.quaternary).opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let primary = snapshot.primaryQuota {
                            QuotaLine(quota: primary)
                        }

                        if let secondary = snapshot.secondaryQuota {
                            QuotaLine(quota: secondary)
                        }

                        if let cost = snapshot.cost {
                            HStack {
                                Image(systemName: "dollarsign.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Cost:")
                                    .font(.caption.weight(.medium))
                                Spacer()
                                Text(cost.formattedCost)
                                    .font(.caption.monospacedDigit())
                            }
                        }
                    }
                }
            } else {
                emptyState
            }
        }
        .padding(.horizontal, 16)
    }

    private struct QuotaLine: View {
        let quota: WidgetQuota

        var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(quota.label)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(Int(quota.percentRemaining))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(WidgetStatusColors.color(for: quota.status))
                }

                if let reset = quota.resetDescription {
                    Text(reset)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }


    // MARK: - accessoryCircular

    private var circularView: some View {
        Group {
            if let snapshot {
                Gauge(value: (snapshot.primaryQuota?.percentRemaining ?? 0) / 100) {
                    Image(systemName: WidgetProviderVisuals.symbolIcon(for: snapshot.providerId))
                } currentValueLabel: {
                    Text("\(Int(snapshot.primaryQuota?.percentRemaining ?? 0))")
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(WidgetStatusColors.color(for: snapshot.overallStatus))
            } else {
                Gauge(value: 0) {
                    Image(systemName: "chart.bar.fill")
                } currentValueLabel: {
                    Text("--")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        }
    }

    // MARK: - accessoryRectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let snapshot {
                HStack(spacing: 4) {
                    Image(systemName: WidgetProviderVisuals.symbolIcon(for: snapshot.providerId))
                        .font(.caption2)
                    Text(snapshot.displayName)
                        .font(.headline)
                        .lineLimit(1)
                }
                .widgetAccentable()

                ProgressView(value: (snapshot.primaryQuota?.percentRemaining ?? 0) / 100)
                    .tint(WidgetStatusColors.color(for: snapshot.overallStatus))

                Text("\(Int(snapshot.primaryQuota?.percentRemaining ?? 0))% remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("burnrate")
                    .font(.headline)
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - accessoryInline

    private var inlineView: some View {
        Group {
            if let snapshot {
                Text("\(snapshot.displayName) \(Int(snapshot.primaryQuota?.percentRemaining ?? 0))%")
            } else {
                Text("burnrate: No data")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open burnrate on Mac to sync data")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func ringProgress(_ snapshot: WidgetProviderSnapshot) -> CGFloat {
        CGFloat(max(0, min(1, (snapshot.primaryQuota?.percentRemaining ?? 0) / 100)))
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
