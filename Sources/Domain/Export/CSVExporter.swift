import Foundation

/// A row of snapshot data for CSV export.
public struct SnapshotExportRow: Sendable {
    public let date: Date
    public let provider: String
    public let sessionPercent: Int
    public let weeklyPercent: Int

    public init(date: Date, provider: String, sessionPercent: Int, weeklyPercent: Int) {
        self.date = date
        self.provider = provider
        self.sessionPercent = sessionPercent
        self.weeklyPercent = weeklyPercent
    }
}

/// Converts snapshot rows into CSV text.
public enum CSVExporter {
    private static let header = "timestamp,provider,session_percent,weekly_percent"

    /// Exports rows as a CSV string with ISO 8601 timestamps.
    public static func export(_ rows: [SnapshotExportRow]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        var lines = [header]
        for row in rows {
            let ts = dateFormatter.string(from: row.date)
            lines.append("\(ts),\(escapeCsvField(row.provider)),\(row.sessionPercent),\(row.weeklyPercent)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escapeCsvField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
