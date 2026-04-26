import Foundation

/// Format options for exporting snapshot data.
public enum ExportFormat: String, CaseIterable, Sendable {
    case json = "JSON"
    case csv = "CSV"
    case markdown = "Markdown"

    public var fileExtension: String {
        switch self {
        case .json: "json"
        case .csv: "csv"
        case .markdown: "md"
        }
    }
}

/// A complete exportable snapshot of all provider data at a point in time.
public struct ExportableSnapshot: Sendable, Equatable {
    public let exportedAt: Date
    public let appVersion: String
    public let providers: [ExportableProvider]

    public init(exportedAt: Date = Date(), appVersion: String, providers: [ExportableProvider]) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.providers = providers
    }
}

/// A single provider's exportable data.
public struct ExportableProvider: Sendable, Equatable {
    public let id: String
    public let name: String
    public let status: String
    public let accountEmail: String?
    public let accountTier: String?
    public let quotas: [ExportableQuota]
    public let costUsage: ExportableCostUsage?
    public let dailyUsage: ExportableDailyUsage?
    public let bedrockUsage: ExportableBedrockUsage?

    public init(
        id: String,
        name: String,
        status: String,
        accountEmail: String? = nil,
        accountTier: String? = nil,
        quotas: [ExportableQuota] = [],
        costUsage: ExportableCostUsage? = nil,
        dailyUsage: ExportableDailyUsage? = nil,
        bedrockUsage: ExportableBedrockUsage? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.accountEmail = accountEmail
        self.accountTier = accountTier
        self.quotas = quotas
        self.costUsage = costUsage
        self.dailyUsage = dailyUsage
        self.bedrockUsage = bedrockUsage
    }
}

public struct ExportableQuota: Sendable, Equatable {
    public let type: String
    public let percentRemaining: Double
    public let percentUsed: Double
    public let status: String
    public let resetsAt: Date?
    public let resetDescription: String?
    public let pace: String?
    public let burnRate: Double?
    public let dollarRemaining: String?

    public init(
        type: String,
        percentRemaining: Double,
        percentUsed: Double,
        status: String,
        resetsAt: Date? = nil,
        resetDescription: String? = nil,
        pace: String? = nil,
        burnRate: Double? = nil,
        dollarRemaining: String? = nil
    ) {
        self.type = type
        self.percentRemaining = percentRemaining
        self.percentUsed = percentUsed
        self.status = status
        self.resetsAt = resetsAt
        self.resetDescription = resetDescription
        self.pace = pace
        self.burnRate = burnRate
        self.dollarRemaining = dollarRemaining
    }
}

public struct ExportableCostUsage: Sendable, Equatable {
    public let totalCost: String
    public let budget: String?
    public let budgetPercentUsed: Double?
    public let apiDuration: String
    public let wallDuration: String
    public let linesAdded: Int
    public let linesRemoved: Int
    public let resetsAt: Date?

    public init(
        totalCost: String,
        budget: String? = nil,
        budgetPercentUsed: Double? = nil,
        apiDuration: String,
        wallDuration: String,
        linesAdded: Int,
        linesRemoved: Int,
        resetsAt: Date? = nil
    ) {
        self.totalCost = totalCost
        self.budget = budget
        self.budgetPercentUsed = budgetPercentUsed
        self.apiDuration = apiDuration
        self.wallDuration = wallDuration
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.resetsAt = resetsAt
    }
}

public struct ExportableDailyUsage: Sendable, Equatable {
    public let todayCost: String
    public let todayTokens: String
    public let todayWorkingTime: String
    public let todaySessions: Int
    public let previousCost: String
    public let previousTokens: String
    public let costDelta: String
    public let tokenDelta: String
    public let timeDelta: String

    public init(
        todayCost: String,
        todayTokens: String,
        todayWorkingTime: String,
        todaySessions: Int,
        previousCost: String,
        previousTokens: String,
        costDelta: String,
        tokenDelta: String,
        timeDelta: String
    ) {
        self.todayCost = todayCost
        self.todayTokens = todayTokens
        self.todayWorkingTime = todayWorkingTime
        self.todaySessions = todaySessions
        self.previousCost = previousCost
        self.previousTokens = previousTokens
        self.costDelta = costDelta
        self.tokenDelta = tokenDelta
        self.timeDelta = timeDelta
    }
}

public struct ExportableBedrockUsage: Sendable, Equatable {
    public let region: String
    public let totalCost: String
    public let totalInvocations: Int
    public let totalTokens: String
    public let dailyBudget: String?
    public let models: [ExportableBedrockModel]

    public init(
        region: String,
        totalCost: String,
        totalInvocations: Int,
        totalTokens: String,
        dailyBudget: String? = nil,
        models: [ExportableBedrockModel] = []
    ) {
        self.region = region
        self.totalCost = totalCost
        self.totalInvocations = totalInvocations
        self.totalTokens = totalTokens
        self.dailyBudget = dailyBudget
        self.models = models
    }
}

public struct ExportableBedrockModel: Sendable, Equatable {
    public let name: String
    public let invocations: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cost: String

    public init(name: String, invocations: Int, inputTokens: Int, outputTokens: Int, cost: String) {
        self.name = name
        self.invocations = invocations
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
    }
}

// MARK: - Formatter

/// Formats an ExportableSnapshot into JSON, CSV, or Markdown.
public enum SnapshotFormatter {

    // MARK: - JSON

    public static func json(_ snapshot: ExportableSnapshot) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var obj: [String: Any] = [
            "exportedAt": iso.string(from: snapshot.exportedAt),
            "appVersion": snapshot.appVersion,
        ]

        var providersArr: [[String: Any]] = []
        for p in snapshot.providers {
            var pObj: [String: Any] = [
                "id": p.id,
                "name": p.name,
                "status": p.status,
            ]
            if let email = p.accountEmail { pObj["accountEmail"] = email }
            if let tier = p.accountTier { pObj["accountTier"] = tier }

            let quotasArr: [[String: Any]] = p.quotas.map { q in
                var qObj: [String: Any] = [
                    "type": q.type,
                    "percentRemaining": round(q.percentRemaining, decimals: 1),
                    "percentUsed": round(q.percentUsed, decimals: 1),
                    "status": q.status,
                ]
                if let r = q.resetsAt { qObj["resetsAt"] = iso.string(from: r) }
                if let rd = q.resetDescription { qObj["resetDescription"] = rd }
                if let pace = q.pace { qObj["pace"] = pace }
                if let br = q.burnRate { qObj["burnRate"] = round(br, decimals: 2) }
                if let dr = q.dollarRemaining { qObj["dollarRemaining"] = dr }
                return qObj
            }
            if !quotasArr.isEmpty { pObj["quotas"] = quotasArr }

            if let c = p.costUsage {
                var cObj: [String: Any] = [
                    "totalCost": c.totalCost,
                    "apiDuration": c.apiDuration,
                    "wallDuration": c.wallDuration,
                    "linesAdded": c.linesAdded,
                    "linesRemoved": c.linesRemoved,
                ]
                if let b = c.budget { cObj["budget"] = b }
                if let bp = c.budgetPercentUsed { cObj["budgetPercentUsed"] = round(bp, decimals: 1) }
                if let r = c.resetsAt { cObj["resetsAt"] = iso.string(from: r) }
                pObj["costUsage"] = cObj
            }

            if let d = p.dailyUsage {
                pObj["dailyUsage"] = [
                    "today": [
                        "cost": d.todayCost,
                        "tokens": d.todayTokens,
                        "workingTime": d.todayWorkingTime,
                        "sessions": d.todaySessions,
                    ],
                    "previous": [
                        "cost": d.previousCost,
                        "tokens": d.previousTokens,
                    ],
                    "delta": [
                        "cost": d.costDelta,
                        "tokens": d.tokenDelta,
                        "time": d.timeDelta,
                    ],
                ] as [String: Any]
            }

            if let b = p.bedrockUsage {
                var bObj: [String: Any] = [
                    "region": b.region,
                    "totalCost": b.totalCost,
                    "totalInvocations": b.totalInvocations,
                    "totalTokens": b.totalTokens,
                ]
                if let db = b.dailyBudget { bObj["dailyBudget"] = db }
                if !b.models.isEmpty {
                    bObj["models"] = b.models.map { m in
                        [
                            "name": m.name,
                            "invocations": m.invocations,
                            "inputTokens": m.inputTokens,
                            "outputTokens": m.outputTokens,
                            "cost": m.cost,
                        ] as [String: Any]
                    }
                }
                pObj["bedrockUsage"] = bObj
            }

            providersArr.append(pObj)
        }
        obj["providers"] = providersArr

        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    // MARK: - CSV

    public static func csv(_ snapshot: ExportableSnapshot) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let header = "timestamp,provider,status,quota_type,percent_remaining,percent_used,resets_at,pace,burn_rate,cost_total,cost_budget"
        var lines = [header]

        for p in snapshot.providers {
            let ts = iso.string(from: snapshot.exportedAt)
            if p.quotas.isEmpty {
                // Provider with no quotas (e.g., cost-only) — still emit a row
                let costTotal = p.costUsage?.totalCost ?? ""
                let costBudget = p.costUsage?.budget ?? ""
                lines.append("\(ts),\(esc(p.name)),\(p.status),,,,,,\(esc(costTotal)),\(esc(costBudget))")
            } else {
                for q in p.quotas {
                    let resetsAt = q.resetsAt.map { iso.string(from: $0) } ?? ""
                    let pace = q.pace ?? ""
                    let burnRate = q.burnRate.map { String(format: "%.2f", $0) } ?? ""
                    let costTotal = p.costUsage?.totalCost ?? ""
                    let costBudget = p.costUsage?.budget ?? ""
                    lines.append(
                        "\(ts),\(esc(p.name)),\(p.status),\(esc(q.type))," +
                        "\(String(format: "%.1f", q.percentRemaining)),\(String(format: "%.1f", q.percentUsed))," +
                        "\(resetsAt),\(pace),\(burnRate),\(esc(costTotal)),\(esc(costBudget))"
                    )
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Markdown

    public static func markdown(_ snapshot: ExportableSnapshot) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = []
        lines.append("## burnrate Snapshot (\(df.string(from: snapshot.exportedAt)))")
        lines.append("")

        // Summary table
        lines.append("| Provider | Status | Quotas | Resets |")
        lines.append("|----------|--------|--------|--------|")

        for p in snapshot.providers {
            let quotaSummary: String
            if p.quotas.isEmpty {
                quotaSummary = p.costUsage.map { "Cost: \($0.totalCost)" } ?? "--"
            } else {
                quotaSummary = p.quotas.map { q in
                    "\(q.type): \(Int(q.percentRemaining))% left"
                }.joined(separator: ", ")
            }

            let resetSummary = p.quotas.compactMap(\.resetDescription).first ?? "--"
            let statusEmoji = statusEmoji(p.status)

            lines.append("| \(p.name) | \(statusEmoji) \(p.status.capitalized) | \(quotaSummary) | \(resetSummary) |")
        }

        // Cost details (if any provider has cost data)
        let costProviders = snapshot.providers.filter { $0.costUsage != nil }
        if !costProviders.isEmpty {
            lines.append("")
            lines.append("### Cost Usage")
            lines.append("")
            for p in costProviders {
                guard let c = p.costUsage else { continue }
                lines.append("**\(p.name)**: \(c.totalCost) spent")
                if let budget = c.budget {
                    lines.append("  - Budget: \(budget)")
                }
                lines.append("  - API time: \(c.apiDuration), Wall time: \(c.wallDuration)")
                lines.append("  - Code: +\(c.linesAdded) / -\(c.linesRemoved) lines")
            }
        }

        // Daily usage (if any provider has it)
        let dailyProviders = snapshot.providers.filter { $0.dailyUsage != nil }
        if !dailyProviders.isEmpty {
            lines.append("")
            lines.append("### Daily Usage")
            lines.append("")
            for p in dailyProviders {
                guard let d = p.dailyUsage else { continue }
                lines.append("**\(p.name)** today: \(d.todayCost) | \(d.todayTokens) tokens | \(d.todayWorkingTime) | \(d.todaySessions) sessions")
                lines.append("  - vs previous: \(d.costDelta) cost, \(d.tokenDelta) tokens, \(d.timeDelta) time")
            }
        }

        // Bedrock details
        let bedrockProviders = snapshot.providers.filter { $0.bedrockUsage != nil }
        if !bedrockProviders.isEmpty {
            lines.append("")
            lines.append("### Bedrock Usage")
            lines.append("")
            for p in bedrockProviders {
                guard let b = p.bedrockUsage else { continue }
                lines.append("**\(p.name)** (\(b.region)): \(b.totalCost) | \(b.totalInvocations) invocations | \(b.totalTokens) tokens")
                if !b.models.isEmpty {
                    for m in b.models {
                        lines.append("  - \(m.name): \(m.cost) (\(m.invocations) calls)")
                    }
                }
            }
        }

        lines.append("")
        lines.append("---")
        lines.append("*Exported by burnrate v\(snapshot.appVersion)*")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Dispatch

    public static func format(_ snapshot: ExportableSnapshot, as format: ExportFormat) -> String {
        switch format {
        case .json: json(snapshot)
        case .csv: csv(snapshot)
        case .markdown: markdown(snapshot)
        }
    }

    // MARK: - Helpers

    private static func esc(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func round(_ value: Double, decimals: Int) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (value * multiplier).rounded() / multiplier
    }

    private static func statusEmoji(_ status: String) -> String {
        switch status.lowercased() {
        case "healthy": return "✅"
        case "warning": return "⚠️"
        case "critical": return "🔴"
        case "depleted": return "⛔"
        default: return "➖"
        }
    }
}
