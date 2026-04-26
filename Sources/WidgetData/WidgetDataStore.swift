import Foundation

/// Reads and writes widget snapshot data for the widget extension.
/// On macOS (non-sandboxed): uses ~/.burnrate/widget-snapshots.json (same dir as settings).
/// On iOS: uses App Group shared container.
public struct WidgetDataStore: Sendable {
    private static let appGroupIdentifier = "group.com.nguyentheanh.burnrate"
    private static let fileName = "widget-snapshots.json"

    private let overrideURL: URL?

    public init(fileURL: URL? = nil) {
        self.overrideURL = fileURL
    }

    private var fileURL: URL? {
        if let overrideURL { return overrideURL }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
            .appendingPathComponent(Self.fileName)
    }

    // MARK: - Write (called by main app after refresh)

    public func write(_ snapshots: [WidgetProviderSnapshot]) {
        guard let url = fileURL else { return }
        do {
            let dir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(snapshots)
            try data.write(to: url, options: .atomic)
        } catch {
            // Silently fail -- widget will show stale or empty data
        }
    }

    // MARK: - Read (called by widget timeline provider)

    public func read() -> [WidgetProviderSnapshot] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url)
        else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([WidgetProviderSnapshot].self, from: data)) ?? []
    }
}
