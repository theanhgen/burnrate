import AppIntents
import WidgetKit

struct ProviderEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "AI Provider")
    nonisolated(unsafe) static var defaultQuery = ProviderEntityQuery()

    var id: String
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
}

struct ProviderEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProviderEntity] {
        identifiers.compactMap { id in
            Self.knownProviders.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [ProviderEntity] {
        Self.knownProviders
    }

    static let knownProviders: [ProviderEntity] = [
        ProviderEntity(id: "claude", displayName: "Claude"),
        ProviderEntity(id: "codex", displayName: "Codex"),
        ProviderEntity(id: "gemini", displayName: "Gemini"),
        ProviderEntity(id: "copilot", displayName: "GitHub Copilot"),
        ProviderEntity(id: "cursor", displayName: "Cursor"),
        ProviderEntity(id: "kimi", displayName: "Kimi"),
        ProviderEntity(id: "kiro", displayName: "Kiro"),
        ProviderEntity(id: "ampcode", displayName: "Amp"),
        ProviderEntity(id: "bedrock", displayName: "AWS Bedrock"),
        ProviderEntity(id: "zai", displayName: "Z.ai"),
        ProviderEntity(id: "antigravity", displayName: "Antigravity"),
        ProviderEntity(id: "minimax", displayName: "MiniMax"),
        ProviderEntity(id: "mistral", displayName: "Mistral"),
    ]
}

struct SelectProviderIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Select Provider"
    nonisolated(unsafe) static var description = IntentDescription("Choose which AI provider to display")

    @Parameter(title: "Provider")
    var provider: ProviderEntity?
}
