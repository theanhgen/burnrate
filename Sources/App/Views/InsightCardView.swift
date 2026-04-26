import SwiftUI
import Domain

/// Displays a single UsageInsight as a compact card.
struct InsightCardView: View {
    let insight: UsageInsight
    let isHeadline: Bool

    init(insight: UsageInsight, isHeadline: Bool = false) {
        self.insight = insight
        self.isHeadline = isHeadline
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: insight.symbolName)
                .font(.system(size: isHeadline ? 14 : 11))
                .foregroundStyle(severityColor)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: isHeadline ? 13 : 11, weight: .semibold))
                    .foregroundStyle(isHeadline ? severityColor : .primary)

                Text(insight.detail)
                    .font(.system(size: isHeadline ? 11 : 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, isHeadline ? 8 : 4)
    }

    private var severityColor: Color {
        switch insight.severity {
        case .positive: .green
        case .neutral: .secondary
        case .caution: .orange
        case .urgent: .red
        }
    }
}

/// Single-line compact insight for the 2-column grid. Detail shown on hover.
struct CompactInsightCell: View {
    let insight: UsageInsight

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: insight.symbolName)
                .font(.system(size: 9))
                .foregroundStyle(severityColor)
                .frame(width: 12, alignment: .center)

            Text(insight.title)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .help(insight.detail)
    }

    private var severityColor: Color {
        switch insight.severity {
        case .positive: .green
        case .neutral: .secondary
        case .caution: .orange
        case .urgent: .red
        }
    }
}
