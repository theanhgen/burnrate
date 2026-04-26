import SwiftUI
import Domain

// MARK: - Data Confidence

/// Represents the confidence level of usage data.
/// Maps burnrate's confidence model onto its probe-based architecture.
enum DataConfidence: String {
    case exact
    case estimated
    case unknown

    var label: String {
        switch self {
        case .exact: "Exact"
        case .estimated: "Est."
        case .unknown: "Unk."
        }
    }
}

// MARK: - Provider Display

/// Static utility providing burnrate visual properties for any provider.
/// Bridges burnrate's 14+ providers into its visual system.
enum ProviderDisplay {
    static func color(for id: String) -> Color {
        switch id {
        case "claude": .orange
        case "codex": .green
        case "gemini": .blue
        case "ampcode": .red
        case "antigravity": .purple
        case "copilot": Color(red: 0.38, green: 0.55, blue: 0.93)
        case "zai": Color(red: 0.35, green: 0.60, blue: 1.0)
        case "bedrock": Color(red: 1.0, green: 0.6, blue: 0.2)
        case "kimi": Color(red: 0.30, green: 0.65, blue: 0.95)
        case "kiro": Color(red: 0.55, green: 0.35, blue: 0.85)
        case "minimax": Color(red: 0.91, green: 0.27, blue: 0.42)
        case "cursor": .teal
        case "mistral": Color(red: 1.0, green: 0.55, blue: 0.0)
        case "alibaba": Color(red: 1.0, green: 0.42, blue: 0.0)
        default: .gray
        }
    }

    static func icon(for id: String) -> String {
        ProviderVisualIdentityLookup.symbolIcon(for: id)
    }

    static func name(for id: String) -> String {
        ProviderVisualIdentityLookup.name(for: id)
    }

    static func initial(for id: String) -> String {
        switch id {
        case "claude": "C"
        case "codex": "X"
        case "gemini": "G"
        case "ampcode": "A"
        case "antigravity": "AG"
        case "copilot": "CP"
        case "zai": "Z"
        case "bedrock": "BR"
        case "kimi": "K"
        case "kiro": "KR"
        case "minimax": "MM"
        case "cursor": "CU"
        case "mistral": "MI"
        case "alibaba": "AL"
        default: String(id.prefix(2).uppercased())
        }
    }

    static func primaryUsageLabel(for id: String) -> String {
        switch id {
        case "claude", "codex": "5h Window"
        case "gemini": "Quota"
        case "ampcode": "Credits"
        case "bedrock": "Budget"
        default: "Quota"
        }
    }

    static func secondaryUsageLabel(for id: String) -> String? {
        switch id {
        case "claude", "codex": "Weekly"
        default: nil
        }
    }

    static func primaryResetStyle(for id: String) -> ResetDisplayStyle {
        switch id {
        case "claude", "codex": .clockTime
        default: .raw
        }
    }

    static func secondaryResetStyle(for id: String) -> ResetDisplayStyle {
        switch id {
        case "claude": .dayAndTime
        case "codex": .timeOnDate
        default: .raw
        }
    }
}

// MARK: - Reset Display Style

enum ResetDisplayStyle {
    case clockTime   // "resets 19:30" + "(26m left)"
    case dayAndTime  // "resets Fri, 09:00" + "(2d 17h left)"
    case timeOnDate  // "resets 20:17 on 25 Mar"
    case dateOnly    // "resets Apr 1"
    case raw         // show label as-is (fallback)
}

// MARK: - AIProvider Extensions

extension AIProvider {
    var confidence: DataConfidence {
        guard let snapshot else { return .unknown }
        if !snapshot.quotas.isEmpty { return .exact }
        if snapshot.costUsage != nil { return .exact }
        return .estimated
    }

    /// Percentage used for the primary (session/5h) quota, 0-100
    var primaryUsedPercent: Double {
        snapshot?.sessionQuota?.percentUsed ?? 0
    }

    /// Percentage used for the secondary (weekly) quota, 0-100
    var weeklyUsedPercent: Double {
        snapshot?.weeklyQuota?.percentUsed ?? 0
    }
}

// MARK: - QuotaMonitor Extensions

extension QuotaMonitor {
    /// Providers sorted for display: Claude first, then alphabetical
    var sortedEnabledProviders: [any AIProvider] {
        enabledProviders.sorted { a, b in
            if a.id == "claude" { return true }
            if b.id == "claude" { return false }
            return a.name < b.name
        }
    }

    /// Top 2 providers by session usage for menu bar label
    func topUsage() -> [(percent: Int, initial: String)] {
        let active: [(Int, String)] = enabledProviders.compactMap { provider in
            guard let snapshot = provider.snapshot,
                  let session = snapshot.sessionQuota else { return nil }
            let pct = Int(session.percentUsed)
            guard pct > 0 else { return nil }
            return (pct, ProviderDisplay.initial(for: provider.id))
        }
        .sorted { $0.0 > $1.0 }

        return Array(active.prefix(2)).map { (percent: $0.0, initial: $0.1) }
    }
}
