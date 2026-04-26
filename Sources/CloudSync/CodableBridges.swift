import Foundation
import Domain

// MARK: - Codable Quota

/// Bridge struct for serializing UsageQuota to/from JSON for CloudKit storage.
struct CodableQuota: Codable, Sendable {
    let percentRemaining: Double
    let quotaType: String       // "session", "weekly", "model:opus", "time:MCP Usage"
    let providerId: String
    let resetsAt: Date?
    let resetText: String?
    let dollarRemaining: String? // Decimal encoded as String for precision

    init(from quota: UsageQuota) {
        self.percentRemaining = quota.percentRemaining
        self.quotaType = Self.encode(quotaType: quota.quotaType)
        self.providerId = quota.providerId
        self.resetsAt = quota.resetsAt
        self.resetText = quota.resetText
        self.dollarRemaining = quota.dollarRemaining.map { "\($0)" }
    }

    func toDomain() -> UsageQuota {
        UsageQuota(
            percentRemaining: percentRemaining,
            quotaType: Self.decode(quotaType: quotaType),
            providerId: providerId,
            resetsAt: resetsAt,
            resetText: resetText,
            dollarRemaining: dollarRemaining.flatMap { Decimal(string: $0) }
        )
    }

    // MARK: - QuotaType Encoding

    private static func encode(quotaType: QuotaType) -> String {
        switch quotaType {
        case .session: return "session"
        case .weekly: return "weekly"
        case .modelSpecific(let name): return "model:\(name)"
        case .timeLimit(let name): return "time:\(name)"
        }
    }

    private static func decode(quotaType encoded: String) -> QuotaType {
        if encoded == "session" { return .session }
        if encoded == "weekly" { return .weekly }
        if encoded.hasPrefix("model:") {
            return .modelSpecific(String(encoded.dropFirst(6)))
        }
        if encoded.hasPrefix("time:") {
            return .timeLimit(String(encoded.dropFirst(5)))
        }
        return .session // fallback
    }
}

// MARK: - Codable Cost Usage

/// Bridge struct for serializing CostUsage to/from JSON for CloudKit storage.
struct CodableCostUsage: Codable, Sendable {
    let totalCost: String       // Decimal as String
    let budget: String?         // Decimal as String
    let apiDuration: TimeInterval
    let wallDuration: TimeInterval
    let linesAdded: Int
    let linesRemoved: Int
    let providerId: String
    let capturedAt: Date
    let resetsAt: Date?
    let resetText: String?

    init(from cost: CostUsage) {
        self.totalCost = "\(cost.totalCost)"
        self.budget = cost.budget.map { "\($0)" }
        self.apiDuration = cost.apiDuration
        self.wallDuration = cost.wallDuration
        self.linesAdded = cost.linesAdded
        self.linesRemoved = cost.linesRemoved
        self.providerId = cost.providerId
        self.capturedAt = cost.capturedAt
        self.resetsAt = cost.resetsAt
        self.resetText = cost.resetText
    }

    func toDomain() -> CostUsage {
        CostUsage(
            totalCost: Decimal(string: totalCost) ?? 0,
            budget: budget.flatMap { Decimal(string: $0) },
            apiDuration: apiDuration,
            wallDuration: wallDuration,
            linesAdded: linesAdded,
            linesRemoved: linesRemoved,
            providerId: providerId,
            capturedAt: capturedAt,
            resetsAt: resetsAt,
            resetText: resetText
        )
    }
}

// MARK: - Codable Account Tier

/// Bridge struct for serializing AccountTier to/from a string for CloudKit storage.
struct CodableAccountTier: Codable, Sendable {
    let value: String

    init(value: String) {
        self.value = value
    }

    init(from tier: AccountTier) {
        switch tier {
        case .claudeMax: self.value = "claudeMax"
        case .claudePro: self.value = "claudePro"
        case .claudeApi: self.value = "claudeApi"
        case .custom(let badge): self.value = "custom:\(badge)"
        }
    }

    func toDomain() -> AccountTier {
        switch value {
        case "claudeMax": return .claudeMax
        case "claudePro": return .claudePro
        case "claudeApi": return .claudeApi
        default:
            if value.hasPrefix("custom:") {
                return .custom(String(value.dropFirst(7)))
            }
            return .custom(value)
        }
    }
}
