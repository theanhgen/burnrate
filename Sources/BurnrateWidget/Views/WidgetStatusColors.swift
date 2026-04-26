import SwiftUI

enum WidgetStatusColors {
    static func color(for status: String) -> Color {
        switch status {
        case "healthy": Color(red: 0.35, green: 0.92, blue: 0.68)
        case "warning": Color(red: 0.98, green: 0.72, blue: 0.35)
        case "critical": Color(red: 0.98, green: 0.42, blue: 0.52)
        case "depleted": Color(red: 0.85, green: 0.25, blue: 0.35)
        default: .green
        }
    }
}
