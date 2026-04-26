import Foundation

/// Pure domain logic for recommending which AI provider/model to use
/// based on task complexity and current quota availability.
public enum ModelRecommendationEngine {

    /// Model tier classification — maps provider models to capability levels.
    private enum ModelTier: Int, Comparable {
        case economy = 0   // Haiku, Flash, cheap models
        case balanced = 1  // Sonnet, Pro models
        case premium = 2   // Opus, Ultra, flagship models

        static func < (lhs: ModelTier, rhs: ModelTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Which tier a task complexity needs at minimum.
    private static func minimumTier(for complexity: TaskComplexity) -> ModelTier {
        switch complexity {
        case .low: .economy
        case .medium: .balanced
        case .high: .premium
        }
    }

    /// Maps a provider ID to its approximate model tier.
    private static func tier(for providerId: String) -> ModelTier {
        switch providerId {
        case "claude": .premium    // Defaults to Opus/Sonnet depending on plan
        case "codex": .premium     // GPT-4.1 class
        case "gemini": .balanced   // 2.5 Pro
        case "copilot": .balanced
        case "amp": .balanced
        case "kiro": .balanced
        case "cursor": .balanced
        case "antigravity": .balanced
        case "zai": .economy
        case "kimi": .economy
        default: .economy
        }
    }

    /// Determines the effective tier based on model-specific quotas.
    /// If the premium model (e.g., opus) is depleted, the provider drops a tier.
    private static func effectiveTier(for provider: any AIProvider) -> ModelTier {
        let baseTier = tier(for: provider.id)
        guard let snapshot = provider.snapshot else { return baseTier }

        let modelQuotas = snapshot.modelSpecificQuotas
        guard !modelQuotas.isEmpty else { return baseTier }

        // Check if the highest-tier model is depleted/critical
        let premiumModels = modelQuotas.filter { quota in
            let name = (quota.quotaType.modelName ?? "").lowercased()
            return name.contains("opus") || name.contains("ultra") || name.contains("4.1")
        }

        if let premiumQuota = premiumModels.first, premiumQuota.status == .depleted || premiumQuota.status == .critical {
            // Premium model unavailable — drop to balanced
            return min(baseTier, .balanced)
        }

        return baseTier
    }

    // MARK: - Public API

    public static func recommend(
        complexity: TaskComplexity,
        providers: [any AIProvider]
    ) -> RecommendationResponse {
        let enabled = providers.filter { $0.isEnabled }

        guard !enabled.isEmpty else {
            return RecommendationResponse(
                recommendation: "No providers enabled",
                reasoning: "Enable at least one AI provider in burnrate settings.",
                alternatives: [],
                warnings: ["No AI providers are currently enabled in burnrate."]
            )
        }

        let minimumTier = minimumTier(for: complexity)
        var warnings: [String] = []

        // Score each provider: (provider, effectiveTier, overallStatus, lowestPercent)
        struct Candidate {
            let provider: any AIProvider
            let tier: ModelTier
            let status: QuotaStatus
            let lowestPercent: Double
        }

        let candidates: [Candidate] = enabled.compactMap { provider in
            guard let snapshot = provider.snapshot else { return nil }
            let status = snapshot.overallStatus
            // Skip depleted providers entirely
            guard status != .depleted else {
                warnings.append("\(provider.name) is depleted — excluded.")
                return nil
            }
            return Candidate(
                provider: provider,
                tier: effectiveTier(for: provider),
                status: status,
                lowestPercent: snapshot.lowestQuota?.percentRemaining ?? 100
            )
        }

        guard !candidates.isEmpty else {
            return RecommendationResponse(
                recommendation: "All providers depleted or have no data",
                reasoning: "Wait for quota resets or check burnrate for reset times.",
                alternatives: [],
                warnings: warnings
            )
        }

        // Sort: prefer closest-matching tier, then healthier status, then more remaining quota.
        // For low-complexity tasks, prefer economy over premium to conserve expensive quota.
        let sorted = candidates.sorted { a, b in
            let aMeetsTier = a.tier >= minimumTier
            let bMeetsTier = b.tier >= minimumTier

            // 1. Providers that meet the minimum tier come first
            if aMeetsTier != bMeetsTier { return aMeetsTier }

            // 2. Among qualifying providers, prefer the closest tier match.
            //    This penalizes over-qualified providers for simple tasks
            //    (e.g., don't burn Opus quota for a typo fix).
            if aMeetsTier && bMeetsTier {
                let aDistance = a.tier.rawValue - minimumTier.rawValue
                let bDistance = b.tier.rawValue - minimumTier.rawValue
                if aDistance != bDistance { return aDistance < bDistance }
            }

            // 3. Among same tier distance, prefer healthier status
            if a.status != b.status { return a.status < b.status }

            // 4. Among same status, prefer more remaining quota
            return a.lowestPercent > b.lowestPercent
        }

        let best = sorted[0]

        // Build reasoning
        var reasoning = "\(best.provider.name) has \(formatPercent(best.lowestPercent))% quota remaining"
        if best.status == .warning {
            reasoning += " (warning level)"
            warnings.append("\(best.provider.name) quota is getting low — consider lighter tasks.")
        } else if best.status == .critical {
            reasoning += " (critical level)"
            warnings.append("\(best.provider.name) quota is critically low.")
        }

        // Check burn rate warnings
        if let burnRate = best.provider.snapshot?.lowestQuota?.burnRate, burnRate > 1.5 {
            warnings.append("\(best.provider.name) burn rate is \(formatPercent(burnRate))x — consuming faster than sustainable.")
        }

        // Reset time info
        if let resetDesc = best.provider.snapshot?.lowestQuota?.resetDescription {
            reasoning += ". \(resetDesc)."
        }

        // Build alternatives (other candidates that also meet minimum tier)
        let alternatives: [AlternativeModel] = sorted.dropFirst().prefix(3).map { candidate in
            AlternativeModel(
                provider: candidate.provider.name,
                status: statusString(candidate.status),
                reason: "\(formatPercent(candidate.lowestPercent))% remaining"
            )
        }

        return RecommendationResponse(
            recommendation: "Use \(best.provider.name)",
            reasoning: reasoning,
            alternatives: alternatives,
            warnings: warnings
        )
    }

    // MARK: - Helpers

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private static func statusString(_ status: QuotaStatus) -> String {
        switch status {
        case .healthy: "healthy"
        case .warning: "warning"
        case .critical: "critical"
        case .depleted: "depleted"
        }
    }
}
