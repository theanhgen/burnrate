import Foundation

// MARK: - QuotaStatusResponse

/// Top-level response for get_quota_status — overview of all providers.
public struct QuotaStatusResponse: Sendable, Codable {
    public let overallStatus: String
    public let providers: [ProviderSummary]
    public let capturedAt: String

    public init(overallStatus: String, providers: [ProviderSummary], capturedAt: String) {
        self.overallStatus = overallStatus
        self.providers = providers
        self.capturedAt = capturedAt
    }
}

/// Summary of a single provider (used in the overview list).
public struct ProviderSummary: Sendable, Codable {
    public let id: String
    public let name: String
    public let status: String
    public let accountTier: String?
    public let snapshotAge: String?
    public let quotas: [QuotaSummary]
    public let modelQuotas: [ModelQuotaSummary]
    public let costUsage: CostSummary?

    public init(
        id: String, name: String, status: String,
        accountTier: String?, snapshotAge: String?, quotas: [QuotaSummary],
        modelQuotas: [ModelQuotaSummary], costUsage: CostSummary?
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.accountTier = accountTier
        self.snapshotAge = snapshotAge
        self.quotas = quotas
        self.modelQuotas = modelQuotas
        self.costUsage = costUsage
    }
}

/// A single quota entry in the summary.
public struct QuotaSummary: Sendable, Codable {
    public let type: String
    public let percentRemaining: Double
    public let status: String
    public let resetsIn: String?
    public let burnRate: Double?

    public init(type: String, percentRemaining: Double, status: String, resetsIn: String?, burnRate: Double?) {
        self.type = type
        self.percentRemaining = percentRemaining
        self.status = status
        self.resetsIn = resetsIn
        self.burnRate = burnRate
    }
}

/// A model-specific quota entry.
public struct ModelQuotaSummary: Sendable, Codable {
    public let model: String
    public let percentRemaining: Double
    public let status: String

    public init(model: String, percentRemaining: Double, status: String) {
        self.model = model
        self.percentRemaining = percentRemaining
        self.status = status
    }
}

/// Cost usage summary.
public struct CostSummary: Sendable, Codable {
    public let totalCost: String
    public let budget: String?
    public let budgetPercentUsed: Double?

    public init(totalCost: String, budget: String?, budgetPercentUsed: Double?) {
        self.totalCost = totalCost
        self.budget = budget
        self.budgetPercentUsed = budgetPercentUsed
    }
}

// MARK: - ProviderDetailResponse

/// Detailed response for get_provider_detail — deep dive on one provider.
public struct ProviderDetailResponse: Sendable, Codable {
    public let id: String
    public let name: String
    public let status: String
    public let accountTier: String?
    public let quotas: [QuotaDetail]
    public let modelQuotas: [ModelQuotaSummary]
    public let costUsage: CostSummary?
    public let capturedAt: String
    public let snapshotAge: String

    public init(
        id: String, name: String, status: String, accountTier: String?,
        quotas: [QuotaDetail], modelQuotas: [ModelQuotaSummary],
        costUsage: CostSummary?, capturedAt: String, snapshotAge: String
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.accountTier = accountTier
        self.quotas = quotas
        self.modelQuotas = modelQuotas
        self.costUsage = costUsage
        self.capturedAt = capturedAt
        self.snapshotAge = snapshotAge
    }
}

/// Detailed quota entry with pace information.
public struct QuotaDetail: Sendable, Codable {
    public let type: String
    public let percentRemaining: Double
    public let percentUsed: Double
    public let status: String
    public let resetsIn: String?
    public let resetsAt: String?
    public let burnRate: Double?
    public let pace: String?
    public let paceInsight: String?

    public init(
        type: String, percentRemaining: Double, percentUsed: Double, status: String,
        resetsIn: String?, resetsAt: String?, burnRate: Double?, pace: String?, paceInsight: String?
    ) {
        self.type = type
        self.percentRemaining = percentRemaining
        self.percentUsed = percentUsed
        self.status = status
        self.resetsIn = resetsIn
        self.resetsAt = resetsAt
        self.burnRate = burnRate
        self.pace = pace
        self.paceInsight = paceInsight
    }
}

// MARK: - RecommendationResponse

/// Response for get_model_recommendation.
public struct RecommendationResponse: Sendable, Codable {
    public let recommendation: String
    public let reasoning: String
    public let alternatives: [AlternativeModel]
    public let warnings: [String]

    public init(recommendation: String, reasoning: String, alternatives: [AlternativeModel], warnings: [String]) {
        self.recommendation = recommendation
        self.reasoning = reasoning
        self.alternatives = alternatives
        self.warnings = warnings
    }
}

/// An alternative model/provider suggestion.
public struct AlternativeModel: Sendable, Codable {
    public let provider: String
    public let status: String
    public let reason: String

    public init(provider: String, status: String, reason: String) {
        self.provider = provider
        self.status = status
        self.reason = reason
    }
}
