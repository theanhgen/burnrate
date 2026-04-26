import Foundation
import Testing
import Domain
@testable import Infrastructure

@Suite
struct CodexDailyUsageAnalyzerTests {
    /// Creates a temp directory mimicking ~/.codex/sessions/YYYY/MM/DD/ structure.
    private func setupTempSessionsDir(
        with jsonlContent: String,
        for date: Date,
        fileName: String = "rollout-test.jsonl"
    ) throws -> URL {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dayDir = tmpDir
            .appendingPathComponent(String(format: "%04d", components.year!))
            .appendingPathComponent(String(format: "%02d", components.month!))
            .appendingPathComponent(String(format: "%02d", components.day!))
        try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)
        let fileURL = dayDir.appendingPathComponent(fileName)
        try jsonlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return tmpDir
    }

    @Test func `analyzes today's usage from JSONL files`() async throws {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowStr = formatter.string(from: now)

        let jsonl = """
        {"timestamp":"\(nowStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"output_tokens":500,"cached_input_tokens":200,"reasoning_output_tokens":100,"total_tokens":1500}},"rate_limits":{}}}
        """
        let sessionsDir = try setupTempSessionsDir(with: jsonl, for: now)
        defer { try? FileManager.default.removeItem(at: sessionsDir) }

        let analyzer = CodexDailyUsageAnalyzer(sessionsDir: sessionsDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.totalTokens == 1500)
        #expect(report.today.totalCost > 0)
        #expect(report.today.sessionCount == 1)
    }

    @Test func `previous day is empty when no data exists`() async throws {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowStr = formatter.string(from: now)

        let jsonl = """
        {"timestamp":"\(nowStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":50,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":150}},"rate_limits":{}}}
        """
        let sessionsDir = try setupTempSessionsDir(with: jsonl, for: now)
        defer { try? FileManager.default.removeItem(at: sessionsDir) }

        let analyzer = CodexDailyUsageAnalyzer(sessionsDir: sessionsDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.previous.isEmpty)
        #expect(report.previous.totalTokens == 0)
    }

    @Test func `produces empty report when no files exist`() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let analyzer = CodexDailyUsageAnalyzer(sessionsDir: tmpDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.isEmpty)
        #expect(report.previous.isEmpty)
    }

    @Test func `separates today and yesterday records`() async throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: now))!.addingTimeInterval(3600 * 12)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let todayStr = formatter.string(from: now)
        let yesterdayStr = formatter.string(from: yesterday)

        // Create today's session file
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let todayJsonl = """
        {"timestamp":"\(todayStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"output_tokens":500,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":1500}},"rate_limits":{}}}
        """
        let yesterdayJsonl = """
        {"timestamp":"\(yesterdayStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":2000,"output_tokens":1000,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":3000}},"rate_limits":{}}}
        """

        // Create today's directory
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let todayDir = tmpDir
            .appendingPathComponent(String(format: "%04d", todayComponents.year!))
            .appendingPathComponent(String(format: "%02d", todayComponents.month!))
            .appendingPathComponent(String(format: "%02d", todayComponents.day!))
        try FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)
        try todayJsonl.write(to: todayDir.appendingPathComponent("rollout-today.jsonl"), atomically: true, encoding: .utf8)

        // Create yesterday's directory
        let yesterdayComponents = calendar.dateComponents([.year, .month, .day], from: yesterday)
        let yesterdayDir = tmpDir
            .appendingPathComponent(String(format: "%04d", yesterdayComponents.year!))
            .appendingPathComponent(String(format: "%02d", yesterdayComponents.month!))
            .appendingPathComponent(String(format: "%02d", yesterdayComponents.day!))
        try FileManager.default.createDirectory(at: yesterdayDir, withIntermediateDirectories: true)
        try yesterdayJsonl.write(to: yesterdayDir.appendingPathComponent("rollout-yesterday.jsonl"), atomically: true, encoding: .utf8)

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let analyzer = CodexDailyUsageAnalyzer(sessionsDir: tmpDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.totalTokens == 1500)
        #expect(report.previous.totalTokens == 3000)
    }

    @Test func `calculates cache stats when cached tokens present`() async throws {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowStr = formatter.string(from: now)

        let jsonl = """
        {"timestamp":"\(nowStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"output_tokens":500,"cached_input_tokens":5000,"reasoning_output_tokens":0,"total_tokens":1500}},"rate_limits":{}}}
        """
        let sessionsDir = try setupTempSessionsDir(with: jsonl, for: now)
        defer { try? FileManager.default.removeItem(at: sessionsDir) }

        let analyzer = CodexDailyUsageAnalyzer(sessionsDir: sessionsDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.cacheStats != nil)
        #expect(report.today.cacheStats?.cacheReadTokens == 5000)
        #expect(report.today.cacheStats?.estimatedSavings ?? 0 > 0)
    }

    @Test func `estimates working time from multiple events`() async throws {
        let now = Date()
        let fiveMinAgo = now.addingTimeInterval(-300) // 5 minutes ago (within 30-min session gap)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fiveMinAgoStr = formatter.string(from: fiveMinAgo)
        let nowStr = formatter.string(from: now)

        let jsonl = """
        {"timestamp":"\(fiveMinAgoStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"output_tokens":500,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":1500}},"rate_limits":{}}}
        {"timestamp":"\(nowStr)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":2000,"output_tokens":1000,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":3000}},"rate_limits":{}}}
        """
        let sessionsDir = try setupTempSessionsDir(with: jsonl, for: now)
        defer { try? FileManager.default.removeItem(at: sessionsDir) }

        let analyzer = CodexDailyUsageAnalyzer(sessionsDir: sessionsDir)
        let report = try await analyzer.analyzeToday()

        // Working time should be approximately 5 minutes (300 seconds)
        #expect(report.today.workingTime >= 290)
        #expect(report.today.workingTime <= 310)
        #expect(report.today.sessionCount == 1)
    }
}
