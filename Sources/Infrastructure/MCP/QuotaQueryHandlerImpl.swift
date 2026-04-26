import Foundation
import Domain

/// Implementation of QuotaQueryHandler that queries a live QuotaMonitor.
/// All access to QuotaMonitor is hopped to @MainActor to match the isolation
/// used by SwiftUI views and the monitoring loop, preventing data races.
public final class QuotaQueryHandlerImpl: QuotaQueryHandler, @unchecked Sendable {
    private let monitor: QuotaMonitor

    public init(monitor: QuotaMonitor) {
        self.monitor = monitor
    }

    public func allProviderStatus() async -> QuotaStatusResponse {
        await MainActor.run {
            MCPResponseBuilder.buildStatusResponse(
                providers: monitor.enabledProviders,
                overallStatus: monitor.overallStatus
            )
        }
    }

    public func providerDetail(id: String) async -> ProviderDetailResult {
        await MainActor.run {
            guard let provider = monitor.provider(for: id) else { return .unknownProvider }
            guard let detail = MCPResponseBuilder.buildDetailResponse(provider: provider) else { return .noDataYet }
            return .success(detail)
        }
    }

    public func modelRecommendation(complexity: TaskComplexity) async -> RecommendationResponse {
        await MainActor.run {
            ModelRecommendationEngine.recommend(
                complexity: complexity,
                providers: monitor.enabledProviders
            )
        }
    }

    public func refreshAll() async -> QuotaStatusResponse {
        // Hop to MainActor for the entire refresh to prevent races with UI observation
        _ = await Task { @MainActor in
            await self.monitor.refreshAll()
        }.value
        return await allProviderStatus()
    }
}
