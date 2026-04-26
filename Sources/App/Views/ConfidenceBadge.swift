import SwiftUI

struct ConfidenceBadge: View {
    let confidence: DataConfidence

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.system(size: 8))
            Text(confidence.label)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor.opacity(0.15))
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch confidence {
        case .exact: "checkmark.circle.fill"
        case .estimated: "tilde.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch confidence {
        case .exact: .green
        case .estimated: .yellow
        case .unknown: .gray
        }
    }

    private var foregroundColor: Color {
        switch confidence {
        case .exact: .green
        case .estimated: .orange
        case .unknown: .secondary
        }
    }
}
