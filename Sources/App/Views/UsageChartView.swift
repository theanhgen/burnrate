import SwiftUI
import Charts
import Domain

enum TimeRange: String, CaseIterable {
    case fiveHours = "5h"
    case oneDay = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case sixtyDays = "60d"
    case ninetyDays = "90d"

    var interval: TimeInterval {
        switch self {
        case .fiveHours: 5 * 3600
        case .oneDay: 24 * 3600
        case .sevenDays: 7 * 24 * 3600
        case .thirtyDays: 30 * 24 * 3600
        case .sixtyDays: 60 * 24 * 3600
        case .ninetyDays: 90 * 24 * 3600
        }
    }

    var sinceDate: Date {
        Date().addingTimeInterval(-interval)
    }
}

/// Usage chart showing quota trends over time.
/// Uses SwiftData-backed SnapshotStore for historical data.
struct UsageChartView: View {
    let providerId: String?  // nil = all
    let monitor: QuotaMonitor
    @State private var selectedRange: TimeRange = .fiveHours
    @State private var snapshots: [UsageSnapshotRecord] = []
    @State private var providerSnapshots: [String: [UsageSnapshotRecord]] = [:]
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Over Time")
                .font(.system(size: 13, weight: .semibold))

            if hasData {
                chart
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("Collecting data...")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            }

            Picker("", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .task(id: "\(providerId ?? "all")-\(selectedRange.rawValue)") { loadData() }
    }

    private var hasData: Bool {
        if providerId != nil {
            return snapshots.contains { $0.session > 0 || $0.weekly > 0 }
        }
        return providerSnapshots.values.contains { records in
            records.contains { $0.session > 0 || $0.weekly > 0 }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if providerId != nil {
            singleProviderChart
        } else {
            multiProviderChart
        }
    }

    private var singleProviderChart: some View {
        Chart {
            ForEach(sessionData, id: \.date) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Usage", point.value)
                )
                .foregroundStyle(by: .value("Type", "Session"))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            ForEach(weeklyData, id: \.date) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Usage", point.value)
                )
                .foregroundStyle(by: .value("Type", "Weekly"))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            RuleMark(y: .value("Limit", 100))
                .foregroundStyle(.red.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

            if let selectedDate, let nearest = nearestSnapshot(to: selectedDate) {
                RuleMark(x: .value("Selected", nearest.date))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .bottom, spacing: 2) {
                        Text(nearest.date, format: .dateTime.hour().minute())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                PointMark(x: .value("Time", nearest.date), y: .value("Usage", nearest.session))
                    .foregroundStyle(providerColor)
                    .symbolSize(30)
                    .annotation(position: .top, spacing: 4) {
                        valueBadge("\(nearest.session)%")
                    }

                if nearest.weekly > 0 {
                    PointMark(x: .value("Time", nearest.date), y: .value("Usage", nearest.weekly))
                        .foregroundStyle(providerColor.opacity(0.5))
                        .symbolSize(30)
                        .annotation(position: .top, spacing: 4) {
                            valueBadge("\(nearest.weekly)%")
                        }
                }
            }
        }
        .chartForegroundStyleScale([
            "Session": providerColor,
            "Weekly": providerColor.opacity(0.5)
        ])
        .chartXSelection(value: $selectedDate)
        .modifier(ChartAxisModifier())
        .chartLegend(.visible)
        .frame(height: 160)
    }

    private var multiProviderChart: some View {
        Chart {
            ForEach(multiProviderPoints) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Usage", point.value)
                )
                .foregroundStyle(by: .value("Provider", point.series))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            RuleMark(y: .value("Limit", 100))
                .foregroundStyle(.red.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

            if let selectedDate {
                let nearestPoints = nearestMultiPoints(to: selectedDate)
                if let first = nearestPoints.first {
                    RuleMark(x: .value("Selected", first.date))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .bottom, spacing: 2) {
                            Text(first.date, format: .dateTime.hour().minute())
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                    ForEach(nearestPoints) { pt in
                        PointMark(x: .value("Time", pt.date), y: .value("Usage", pt.value))
                            .foregroundStyle(by: .value("Provider", pt.series))
                            .symbolSize(30)
                            .annotation(position: .top, spacing: 4) {
                                valueBadge("\(pt.value)%")
                            }
                    }
                }
            }
        }
        .chartForegroundStyleScale(
            domain: multiProviderNames,
            range: multiProviderColorValues
        )
        .chartXSelection(value: $selectedDate)
        .modifier(ChartAxisModifier())
        .chartLegend(.visible)
        .frame(height: 160)
    }

    private var multiProviderNameColorPairs: [(String, Color)] {
        providerSnapshots.keys
            .filter { providerSnapshots[$0]?.contains { $0.session > 0 || $0.weekly > 0 } == true }
            .map { (ProviderDisplay.name(for: $0), ProviderDisplay.color(for: $0)) }
            .sorted { $0.0 < $1.0 }
    }

    private var multiProviderNames: [String] {
        multiProviderNameColorPairs.map(\.0)
    }

    private var multiProviderColorValues: [Color] {
        multiProviderNameColorPairs.map(\.1)
    }

    private struct ChartAxisModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .chartYScale(domain: 0...110)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)%")
                                .font(.system(size: 9))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
        }
    }

    // MARK: - Hover Helpers

    private struct NearestSnapshot {
        let date: Date
        let session: Int
        let weekly: Int
    }

    private func nearestSnapshot(to date: Date) -> NearestSnapshot? {
        let sampled = downsample(snapshots, maxPoints: 120)
        guard !sampled.isEmpty else { return nil }
        let target = date.timeIntervalSince1970
        let closest = sampled.min(by: { abs($0.ts - target) < abs($1.ts - target) })!
        return NearestSnapshot(
            date: Date(timeIntervalSince1970: closest.ts),
            session: closest.session,
            weekly: closest.weekly
        )
    }

    private func nearestMultiPoints(to date: Date) -> [MultiPoint] {
        let target = date.timeIntervalSince1970
        var results: [MultiPoint] = []
        for (pid, records) in providerSnapshots {
            guard records.contains(where: { $0.session > 0 || $0.weekly > 0 }) else { continue }
            let sampled = downsample(records, maxPoints: 80)
            guard let closest = sampled.min(by: { abs($0.ts - target) < abs($1.ts - target) }) else { continue }
            let name = ProviderDisplay.name(for: pid)
            results.append(MultiPoint(
                date: Date(timeIntervalSince1970: closest.ts),
                value: closest.session,
                series: name
            ))
        }
        return results.sorted { $0.value > $1.value }
    }

    private func valueBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Data

    private struct ChartPoint {
        let date: Date
        let value: Int
    }

    private struct MultiPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Int
        let series: String
    }

    private var sessionData: [ChartPoint] {
        let sampled = downsample(snapshots, maxPoints: 120)
        return sampled.map { ChartPoint(date: Date(timeIntervalSince1970: $0.ts), value: $0.session) }
    }

    private var weeklyData: [ChartPoint] {
        let sampled = downsample(snapshots, maxPoints: 120)
        return sampled.map { ChartPoint(date: Date(timeIntervalSince1970: $0.ts), value: $0.weekly) }
    }

    private var multiProviderPoints: [MultiPoint] {
        var points: [MultiPoint] = []
        for (pid, records) in providerSnapshots {
            guard records.contains(where: { $0.session > 0 || $0.weekly > 0 }) else { continue }
            let sampled = downsample(records, maxPoints: 80)
            let name = ProviderDisplay.name(for: pid)
            for r in sampled {
                points.append(MultiPoint(
                    date: Date(timeIntervalSince1970: r.ts),
                    value: r.session,
                    series: name
                ))
            }
        }
        return points
    }

    private func downsample(_ data: [UsageSnapshotRecord], maxPoints: Int) -> [UsageSnapshotRecord] {
        guard data.count > maxPoints else { return data }
        let step = data.count / maxPoints
        return stride(from: 0, to: data.count, by: step).map { data[$0] }
    }

    @MainActor
    private func loadData() {
        let store = BurnrateSnapshotStore.shared
        if let pid = providerId {
            snapshots = store.query(provider: pid, since: selectedRange.sinceDate)
            providerSnapshots = [:]
        } else {
            snapshots = []
            var byProvider: [String: [UsageSnapshotRecord]] = [:]
            for provider in monitor.enabledProviders {
                let records = store.query(provider: provider.id, since: selectedRange.sinceDate)
                if records.contains(where: { $0.session > 0 || $0.weekly > 0 }) {
                    byProvider[provider.id] = records
                }
            }
            providerSnapshots = byProvider
        }
    }

    private var providerColor: Color {
        if let pid = providerId {
            return ProviderDisplay.color(for: pid)
        }
        return .orange
    }
}
