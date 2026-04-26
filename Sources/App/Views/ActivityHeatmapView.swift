import SwiftUI

struct ActivityHeatmapView: View {
    let providerId: String?  // nil = all
    @State private var dayCounts: [String: Int] = [:]
    @State private var hoveredCell: CellData?

    private let weeks = 13  // ~90 days
    private let cellSize: CGFloat = 9
    private let cellSpacing: CGFloat = 2
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Activity")
                .font(.system(size: 13, weight: .semibold))

            if dayCounts.isEmpty {
                Text("No activity data")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    monthLabels
                    heatmapGrid
                }
            }
        }
        .task(id: providerId) { loadActivityData() }
    }

    private var monthLabels: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 28)

            let calendar = Calendar.current
            let today = Date()
            let monthPositions = computeMonthPositions(today: today, calendar: calendar)

            ForEach(monthPositions, id: \.offset) { mp in
                Text(mp.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: CGFloat(mp.width) * 11, alignment: .leading)
            }
            Spacer()
        }
    }

    private var heatmapGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 1) {
                ForEach(0..<7, id: \.self) { day in
                    Text(dayLabels[day])
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: cellSize, alignment: .trailing)
                }
            }
            .padding(.trailing, 4)

            let grid = buildGrid()
            HStack(spacing: cellSpacing) {
                ForEach(0..<grid.count, id: \.self) { weekIdx in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            if weekIdx < grid.count && dayIdx < grid[weekIdx].count {
                                let cell = grid[weekIdx][dayIdx]
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(cellColor(count: cell.count, isFuture: cell.isFuture))
                                    .frame(width: cellSize, height: cellSize)
                                    .onHover { hovering in
                                        hoveredCell = hovering && !cell.isFuture ? cell : nil
                                    }
                                    .overlay {
                                        if hoveredCell?.date == cell.date && !cell.isFuture {
                                            RoundedRectangle(cornerRadius: 1.5)
                                                .stroke(.white.opacity(0.6), lineWidth: 1)
                                        }
                                    }
                                    .popover(isPresented: Binding(
                                        get: { hoveredCell?.date == cell.date && !cell.isFuture && !cell.date.isEmpty },
                                        set: { if !$0 { hoveredCell = nil } }
                                    ), arrowEdge: .bottom) {
                                        cellTooltip(cell)
                                    }
                            }
                        }
                    }
                }
            }
        }
    }

    private func cellTooltip(_ cell: CellData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(formattedDate(cell.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Circle()
                    .fill(cell.count > 0 ? baseColor : .secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(cell.count == 0 ? "No activity" : "\(cell.count) active \(cell.count == 1 ? "hour" : "hours")")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .padding(8)
    }

    private func formattedDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEE, MMM d"
        return outputFormatter.string(from: date)
    }

    // MARK: - Grid computation

    private struct CellData {
        let date: String
        let count: Int
        let isFuture: Bool
        var tooltip: String {
            if isFuture { return "" }
            return count == 0 ? "\(date): no activity" : "\(date): \(count) active hours"
        }
    }

    private func buildGrid() -> [[CellData]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = (calendar.component(.weekday, from: today) + 5) % 7

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var grid: [[CellData]] = []

        for week in 0..<weeks {
            var weekCells: [CellData] = []
            for day in 0..<7 {
                let gridStartOffset = (weeks - 1) * 7 + todayWeekday
                let cellOffset = gridStartOffset - (week * 7 + day)

                if cellOffset < 0 {
                    weekCells.append(CellData(date: "", count: 0, isFuture: true))
                } else {
                    let date = calendar.date(byAdding: .day, value: -cellOffset, to: today)!
                    let dateStr = formatter.string(from: date)
                    let count = dayCounts[dateStr] ?? 0
                    weekCells.append(CellData(date: dateStr, count: count, isFuture: false))
                }
            }
            grid.append(weekCells)
        }

        return grid
    }

    private struct MonthPosition: Identifiable {
        let offset: Int
        let label: String
        let width: Int
        var id: Int { offset }
    }

    private func computeMonthPositions(today: Date, calendar: Calendar) -> [MonthPosition] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        let todayWeekday = (calendar.component(.weekday, from: today) + 5) % 7
        let startOffset = (weeks - 1) * 7 + todayWeekday
        let startDate = calendar.date(byAdding: .day, value: -startOffset, to: today)!

        var positions: [MonthPosition] = []
        var currentMonth = -1
        var weekCount = 0
        var lastMonthStart = 0

        for w in 0..<weeks {
            let weekDate = calendar.date(byAdding: .day, value: w * 7, to: startDate)!
            let month = calendar.component(.month, from: weekDate)

            if month != currentMonth {
                if currentMonth != -1 {
                    positions.append(MonthPosition(
                        offset: lastMonthStart,
                        label: formatter.string(from: calendar.date(byAdding: .day, value: lastMonthStart * 7, to: startDate)!),
                        width: weekCount
                    ))
                }
                currentMonth = month
                lastMonthStart = w
                weekCount = 1
            } else {
                weekCount += 1
            }
        }
        if weekCount > 0 {
            positions.append(MonthPosition(
                offset: lastMonthStart,
                label: formatter.string(from: calendar.date(byAdding: .day, value: lastMonthStart * 7, to: startDate)!),
                width: weekCount
            ))
        }

        return positions
    }

    // MARK: - Colors

    private func cellColor(count: Int, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        if count == 0 { return baseColor.opacity(0.08) }

        let maxCount = max(dayCounts.values.max() ?? 1, 1)
        let intensity = min(Double(count) / Double(maxCount), 1.0)

        if intensity > 0.75 { return baseColor.opacity(0.9) }
        if intensity > 0.5 { return baseColor.opacity(0.6) }
        if intensity > 0.25 { return baseColor.opacity(0.4) }
        return baseColor.opacity(0.2)
    }

    private var baseColor: Color {
        if let pid = providerId {
            return ProviderDisplay.color(for: pid)
        }
        return .purple
    }

    // MARK: - Data loading

    @MainActor
    private func loadActivityData() {
        let store = BurnrateSnapshotStore.shared
        let since = Date().addingTimeInterval(-90 * 24 * 3600)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "yyyy-MM-dd-HH"

        if let pid = providerId {
            let records = store.query(provider: pid, since: since)
            // Count unique active hours per day (avoids inflated counts from frequent polling)
            var seenHours: Set<String> = []
            var counts: [String: Int] = [:]
            for record in records {
                let date = Date(timeIntervalSince1970: record.ts)
                let hourKey = hourFormatter.string(from: date)
                if seenHours.insert(hourKey).inserted {
                    let dayKey = dayFormatter.string(from: date)
                    counts[dayKey, default: 0] += 1
                }
            }
            dayCounts = counts
        } else {
            let records = store.queryAll(since: since)
            // Count unique (provider, hour) pairs per day
            var seenHours: Set<String> = []
            var counts: [String: Int] = [:]
            for record in records {
                let date = Date(timeIntervalSince1970: record.ts)
                let hourKey = "\(record.provider)-\(hourFormatter.string(from: date))"
                if seenHours.insert(hourKey).inserted {
                    let dayKey = dayFormatter.string(from: date)
                    counts[dayKey, default: 0] += 1
                }
            }
            dayCounts = counts
        }
    }
}
