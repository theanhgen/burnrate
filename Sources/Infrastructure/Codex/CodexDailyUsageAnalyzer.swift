import Foundation
import Domain

/// Analyzes Codex session JSONL files to produce daily usage reports.
/// Reads from ~/.codex/sessions/YYYY/MM/DD/*.jsonl
public struct CodexDailyUsageAnalyzer: DailyUsageAnalyzing, Sendable {
    private let sessionsDir: URL
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        sessionsDir: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/sessions"),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionsDir = sessionsDir
        self.calendar = calendar
        self.now = now
    }

    public func analyzeToday() async throws -> DailyUsageReport {
        let currentDate = now()
        let todayStart = calendar.startOfDay(for: currentDate)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!

        let todayRecords = parseRecords(for: todayStart)
        let yesterdayRecords = parseRecords(for: yesterdayStart)

        AppLog.probes.info("CodexDailyUsage: today=\(todayRecords.count) records, yesterday=\(yesterdayRecords.count) records")

        let todayStat = aggregate(records: todayRecords, date: todayStart)
        let yesterdayStat = aggregate(records: yesterdayRecords, date: yesterdayStart)

        AppLog.probes.info("CodexDailyUsage: today=\(todayStat.formattedCost)/\(todayStat.formattedTokens), yesterday=\(yesterdayStat.formattedCost)/\(yesterdayStat.formattedTokens)")

        return DailyUsageReport(today: todayStat, previous: yesterdayStat)
    }

    // MARK: - Private

    /// Parse all JSONL files for a given date.
    /// Codex organizes sessions by date: ~/.codex/sessions/YYYY/MM/DD/*.jsonl
    private func parseRecords(for date: Date) -> [CodexTokenUsageRecord] {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return [] }

        let dayDir = sessionsDir
            .appendingPathComponent(String(format: "%04d", year))
            .appendingPathComponent(String(format: "%02d", month))
            .appendingPathComponent(String(format: "%02d", day))

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: dayDir.path) else { return [] }

        guard let files = try? fileManager.contentsOfDirectory(
            at: dayDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let parser = CodexSessionJSONLParser()
        var allRecords: [CodexTokenUsageRecord] = []

        for file in files where file.pathExtension == "jsonl" {
            if let records = try? parser.parse(fileURL: file) {
                allRecords.append(contentsOf: records)
            }
        }

        return allRecords
    }

    private func aggregate(records: [CodexTokenUsageRecord], date: Date) -> DailyUsageStat {
        guard !records.isEmpty else { return .empty(for: date) }

        var totalCost: Decimal = 0
        var totalTokens = 0

        for record in records {
            totalCost += CodexModelPricing.cost(for: record)
            totalTokens += record.totalTokens
        }

        // Estimate working time from timestamps (30-minute gap = new session)
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        var workingTime: TimeInterval = 0
        var sessionCount = 1
        var sessionStart = sortedRecords[0].timestamp
        var lastTimestamp = sortedRecords[0].timestamp

        for record in sortedRecords.dropFirst() {
            let gap = record.timestamp.timeIntervalSince(lastTimestamp)
            if gap > 1800 { // 30 minute gap = new session
                workingTime += lastTimestamp.timeIntervalSince(sessionStart)
                sessionStart = record.timestamp
                sessionCount += 1
            }
            lastTimestamp = record.timestamp
        }
        workingTime += lastTimestamp.timeIntervalSince(sessionStart)

        // Cache stats
        let cacheStats = buildCacheStats(records: records)

        return DailyUsageStat(
            date: date,
            totalCost: totalCost,
            totalTokens: totalTokens,
            workingTime: workingTime,
            sessionCount: sessionCount,
            cacheStats: cacheStats
        )
    }

    private func buildCacheStats(records: [CodexTokenUsageRecord]) -> CacheStats? {
        var totalCacheRead = 0

        for record in records {
            totalCacheRead += record.cachedInputTokens
        }

        guard totalCacheRead > 0 else { return nil }

        // Savings = cached reads charged at cached rate instead of full input rate
        let p = CodexModelPricing.defaultPrice
        let savingsPerToken = p.inputPer1M - p.cachedInputPer1M
        let totalSavings = Decimal(totalCacheRead) / 1_000_000 * savingsPerToken

        return CacheStats(
            cacheReadTokens: totalCacheRead,
            cacheCreationTokens: 0, // Codex doesn't expose cache creation tokens
            estimatedSavings: totalSavings
        )
    }
}
