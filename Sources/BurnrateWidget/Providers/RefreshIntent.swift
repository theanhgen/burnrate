import AppIntents
import WidgetKit

public struct RefreshIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Quotas"
    public static let description = IntentDescription("Triggers a refresh of AI provider quotas.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        // Reloading timelines will cause the providers to fetch latest data.
        // On iOS: Fetches from CloudKit (synced by Mac app).
        // On macOS: Reads from the local shared App Group file.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
