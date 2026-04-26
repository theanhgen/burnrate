import SwiftUI
import Domain

/// Displays a single usage quota as a labeled progress bar with reset time.
/// Adapted from burnrate's design to consume its UsageQuota domain model.
struct UsageBarView: View {
    let label: String
    let quota: UsageQuota
    let color: Color
    var resetStyle: ResetDisplayStyle = .raw

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Row 1: label + reset info
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                resetText
            }

            // Row 2: bar + time remaining + percentage
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.12))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: max(geo.size.width * percentage, 0), height: 4)
                    }
                }
                .frame(height: 4)

                if let remaining = timeRemainingText {
                    Text(remaining)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }

                Text("\(Int(quota.percentUsed))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(percentageColor)
                    .fixedSize()
            }
        }
    }

    /// Fraction 0-1 for bar width
    private var percentage: Double {
        min(quota.percentUsed / 100.0, 1.0)
    }

    // MARK: - Reset text (right side of header row)

    @ViewBuilder
    private var resetText: some View {
        if let resetDate = quota.resetsAt {
            switch resetStyle {
            case .clockTime:
                Text("resets \(Self.clockTimeString(resetDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            case .dayAndTime:
                Text("resets \(Self.dayAndTimeString(resetDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            case .timeOnDate:
                Text("resets \(Self.timeOnDateString(resetDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            case .dateOnly:
                Text("resets \(Self.dateOnlyString(resetDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            case .raw:
                if let text = quota.resetText {
                    Text(text)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        } else if let text = quota.resetText {
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        } else if quota.isDollarBased, let formatted = quota.formattedDollarRemaining {
            Text(formatted)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Time remaining (next to bar)

    private var timeRemainingText: String? {
        guard let resetDate = quota.resetsAt else { return nil }
        let interval = resetDate.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let mins = totalMinutes % 60

        switch resetStyle {
        case .clockTime:
            if hours > 0 {
                return "(\(hours)h \(mins)m left)"
            } else {
                return "(\(mins)m left)"
            }
        case .dayAndTime, .timeOnDate:
            if days > 0 {
                return "(\(days)d \(hours)h left)"
            } else if hours > 0 {
                return "(\(hours)h \(mins)m left)"
            } else {
                return "(\(mins)m left)"
            }
        case .dateOnly, .raw:
            return nil
        }
    }

    // MARK: - Formatting helpers

    static func clockTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func dayAndTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    static func timeOnDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm 'on' d MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    static func dateOnlyString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Colors

    private var barColor: Color {
        if percentage > 0.9 { return .red }
        if percentage > 0.7 { return .orange }
        return color
    }

    private var percentageColor: Color {
        if percentage > 0.9 { return .red }
        if percentage > 0.7 { return .orange }
        return .primary
    }
}
