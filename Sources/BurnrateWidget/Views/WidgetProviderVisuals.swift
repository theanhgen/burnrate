import SwiftUI

enum WidgetProviderVisuals {
    static func symbolIcon(for providerId: String) -> String {
        switch providerId {
        case "claude": "staroflife.fill"
        case "codex": "chevron.left.forwardslash.chevron.right"
        case "gemini": "sparkles"
        case "copilot": "chevron.left.forwardslash.chevron.right"
        case "antigravity": "wand.and.stars"
        case "zai": "z.square.fill"
        case "bedrock": "cloud.fill"
        case "ampcode": "bolt.fill"
        case "kimi": "k.square.fill"
        case "kiro": "wand.and.stars.inverse"
        case "minimax": "waveform"
        case "cursor": "cursorarrow.rays"
        case "mistral": "cat.fill"
        default: "questionmark.circle.fill"
        }
    }

    static func color(for providerId: String, scheme: ColorScheme = .dark) -> Color {
        switch providerId {
        case "claude":
            scheme == .dark
                ? Color(red: 0.95, green: 0.55, blue: 0.50)
                : Color(red: 0.95, green: 0.48, blue: 0.38)
        case "codex":
            scheme == .dark
                ? Color(red: 0.30, green: 0.85, blue: 0.78)
                : Color(red: 0.18, green: 0.72, blue: 0.68)
        case "gemini":
            scheme == .dark
                ? Color(red: 0.95, green: 0.78, blue: 0.35)
                : Color(red: 0.92, green: 0.72, blue: 0.28)
        case "copilot":
            scheme == .dark
                ? Color(red: 0.38, green: 0.55, blue: 0.93)
                : Color(red: 0.26, green: 0.43, blue: 0.82)
        case "antigravity":
            scheme == .dark
                ? Color(red: 0.72, green: 0.35, blue: 0.85)
                : Color(red: 0.58, green: 0.22, blue: 0.72)
        case "zai":
            scheme == .dark
                ? Color(red: 0.35, green: 0.60, blue: 1.0)
                : Color(red: 0.23, green: 0.51, blue: 0.96)
        case "bedrock":
            scheme == .dark
                ? Color(red: 1.0, green: 0.6, blue: 0.2)
                : Color(red: 0.92, green: 0.5, blue: 0.15)
        case "ampcode":
            scheme == .dark
                ? Color(red: 0.95, green: 0.30, blue: 0.25)
                : Color(red: 0.90, green: 0.25, blue: 0.20)
        case "kimi":
            scheme == .dark
                ? Color(red: 0.30, green: 0.65, blue: 0.95)
                : Color(red: 0.20, green: 0.55, blue: 0.85)
        case "kiro":
            scheme == .dark
                ? Color(red: 0.55, green: 0.35, blue: 0.85)
                : Color(red: 0.45, green: 0.25, blue: 0.75)
        case "minimax":
            scheme == .dark
                ? Color(red: 0.91, green: 0.27, blue: 0.42)
                : Color(red: 0.82, green: 0.20, blue: 0.35)
        case "cursor":
            scheme == .dark
                ? Color(red: 0.20, green: 0.78, blue: 0.82)
                : Color(red: 0.12, green: 0.62, blue: 0.66)
        case "mistral":
            scheme == .dark
                ? Color(red: 1.0, green: 0.55, blue: 0.0)
                : Color(red: 0.90, green: 0.45, blue: 0.0)
        default:
            .purple
        }
    }
}
