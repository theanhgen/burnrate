import Foundation

/// Result of a provider detail query, distinguishing error cases.
public enum ProviderDetailResult: Sendable {
    case success(ProviderDetailResponse)
    case unknownProvider
    case noDataYet
}

/// Protocol for handling MCP API queries against live quota data.
/// Implemented in Infrastructure layer with access to QuotaMonitor.
public protocol QuotaQueryHandler: Sendable {
    /// Returns status overview of all enabled providers.
    func allProviderStatus() async -> QuotaStatusResponse

    /// Returns detailed snapshot for a single provider.
    func providerDetail(id: String) async -> ProviderDetailResult

    /// Returns model/provider recommendation for a given task complexity.
    func modelRecommendation(complexity: TaskComplexity) async -> RecommendationResponse

    /// Triggers a refresh of all providers and returns updated status.
    func refreshAll() async -> QuotaStatusResponse
}
