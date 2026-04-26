import Foundation
import Domain

/// Installs and uninstalls the burnrate MCP server configuration
/// in ~/.claude/settings.json so Claude Code can discover it.
public enum MCPInstaller {
    /// The settings file path (same as HookInstaller)
    public static var settingsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }

    /// The MCP server name used in settings.json
    static let serverName = "burnrate"

    /// Resolves the path to the burnrate-mcp binary.
    /// Checks: app bundle first, then common install locations.
    public static func resolveBinaryPath() -> String? {
        // 1. Inside the main app bundle
        if let bundlePath = Bundle.main.path(forAuxiliaryExecutable: "burnrate-mcp") {
            return bundlePath
        }

        // 2. Homebrew
        let homebrewPath = "/usr/local/bin/burnrate-mcp"
        if FileManager.default.isExecutableFile(atPath: homebrewPath) {
            return homebrewPath
        }

        // 3. ARM Homebrew
        let armHomebrewPath = "/opt/homebrew/bin/burnrate-mcp"
        if FileManager.default.isExecutableFile(atPath: armHomebrewPath) {
            return armHomebrewPath
        }

        return nil
    }

    /// Installs the burnrate MCP server into Claude Code's settings.
    /// Preserves existing MCP servers from other tools.
    public static func install(binaryPath: String? = nil) throws {
        guard let path = binaryPath ?? resolveBinaryPath() else {
            throw InstallerError.binaryNotFound
        }

        var settings = try readOrCreateSettings()
        var mcpServers = settings["mcpServers"] as? [String: Any] ?? [String: Any]()

        mcpServers[serverName] = [
            "command": path,
            "args": [String](),
        ] as [String: Any]

        settings["mcpServers"] = mcpServers
        try writeSettings(settings)
    }

    /// Removes the burnrate MCP server from Claude Code's settings.
    /// Preserves other MCP servers.
    public static func uninstall() throws {
        guard var settings = try? readOrCreateSettings() else { return }
        guard var mcpServers = settings["mcpServers"] as? [String: Any] else { return }

        mcpServers.removeValue(forKey: serverName)

        if mcpServers.isEmpty {
            settings.removeValue(forKey: "mcpServers")
        } else {
            settings["mcpServers"] = mcpServers
        }

        try writeSettings(settings)
    }

    /// Checks if the burnrate MCP server is currently configured.
    public static func isInstalled() -> Bool {
        guard let settings = try? readOrCreateSettings(),
              let mcpServers = settings["mcpServers"] as? [String: Any] else {
            return false
        }
        return mcpServers[serverName] != nil
    }

    // MARK: - Private

    enum InstallerError: Error, LocalizedError {
        case binaryNotFound
        case corruptedSettingsFile(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                "burnrate-mcp binary not found. Build the burnrate-mcp target first."
            case .corruptedSettingsFile(let path):
                "Failed to parse \(path) — file may be corrupted."
            }
        }
    }

    static func readOrCreateSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsPath) else {
            return [String: Any]()
        }

        guard let data = FileManager.default.contents(atPath: settingsPath) else {
            return [String: Any]()
        }

        if data.isEmpty {
            return [String: Any]()
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InstallerError.corruptedSettingsFile(settingsPath)
        }

        return json
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        let directory = (settingsPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
    }
}
