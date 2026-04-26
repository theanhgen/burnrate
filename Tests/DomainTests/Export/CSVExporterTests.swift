import Testing
import Foundation
@testable import Domain

@Suite
struct CSVExporterTests {

    @Test
    func `exports header and rows with ISO 8601 timestamps`() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        let rows = [
            SnapshotExportRow(date: date, provider: "claude", sessionPercent: 45, weeklyPercent: 30),
        ]

        let csv = CSVExporter.export(rows)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines[0] == "timestamp,provider,session_percent,weekly_percent")
        #expect(lines[1].hasPrefix("2023-11-14T"))
        #expect(lines[1].hasSuffix(",claude,45,30"))
    }

    @Test
    func `exports multiple rows in order`() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            SnapshotExportRow(date: base, provider: "claude", sessionPercent: 10, weeklyPercent: 20),
            SnapshotExportRow(date: base.addingTimeInterval(60), provider: "codex", sessionPercent: 50, weeklyPercent: 60),
        ]

        let csv = CSVExporter.export(rows)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 4) // header + 2 rows + trailing empty
        #expect(lines[1].contains("claude"))
        #expect(lines[2].contains("codex"))
    }

    @Test
    func `empty rows produces header only`() {
        let csv = CSVExporter.export([])
        #expect(csv == "timestamp,provider,session_percent,weekly_percent\n")
    }

    @Test
    func `escapes provider names with commas`() {
        let row = SnapshotExportRow(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            provider: "provider,with,commas",
            sessionPercent: 10,
            weeklyPercent: 20
        )

        let csv = CSVExporter.export([row])
        #expect(csv.contains("\"provider,with,commas\""))
    }

    @Test
    func `escapes provider names with quotes`() {
        let row = SnapshotExportRow(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            provider: "provider\"quoted",
            sessionPercent: 10,
            weeklyPercent: 20
        )

        let csv = CSVExporter.export([row])
        #expect(csv.contains("\"provider\"\"quoted\""))
    }
}
