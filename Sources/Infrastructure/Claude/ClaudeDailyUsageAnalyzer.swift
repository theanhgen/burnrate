import Foundation
import Domain

/// Analyzes Claude Code session JSONL files to produce daily usage reports.
/// Reads from ~/.claude/projects/*/*.jsonl
public struct ClaudeDailyUsageAnalyzer: DailyUsageAnalyzing, Sendable {
    private let claudeDir: URL
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        claudeDir: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude"),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.claudeDir = claudeDir
        self.calendar = calendar
        self.now = now
    }

    public func analyzeToday() async throws -> DailyUsageReport {
        let currentDate = now()
        let todayStart = calendar.startOfDay(for: currentDate)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!

        // Only scan files modified in the last 2 days for performance
        let projectsDir = claudeDir.appendingPathComponent("projects")
        let jsonlFiles = findRecentJSONLFiles(in: projectsDir, since: yesterdayStart)

        AppLog.probes.info("DailyUsage: scanning \(jsonlFiles.count) recent JSONL files")

        // Parse files and collect records
        let parser = SessionJSONLParser()
        var allRecords: [TokenUsageRecord] = []
        for fileURL in jsonlFiles {
            if let records = try? parser.parse(fileURL: fileURL) {
                allRecords.append(contentsOf: records)
            }
        }

        AppLog.probes.info("DailyUsage: found \(allRecords.count) token records")

        // Partition into today and yesterday
        let todayRecords = allRecords.filter { record in
            record.timestamp >= todayStart && record.timestamp < todayStart.addingTimeInterval(86400)
        }
        let yesterdayRecords = allRecords.filter { record in
            record.timestamp >= yesterdayStart && record.timestamp < todayStart
        }

        // Aggregate stats
        let todayStat = aggregate(records: todayRecords, date: todayStart)
        let yesterdayStat = aggregate(records: yesterdayRecords, date: yesterdayStart)

        AppLog.probes.info("DailyUsage: today=\(todayStat.formattedCost)/\(todayStat.formattedTokens), yesterday=\(yesterdayStat.formattedCost)/\(yesterdayStat.formattedTokens)")

        return DailyUsageReport(today: todayStat, previous: yesterdayStat)
    }

    // MARK: - Private

    /// Only find JSONL files modified since the given date (performance optimization).
    private func findRecentJSONLFiles(in directory: URL, since: Date) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            // Only include files modified since yesterday
            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate >= since {
                files.append(fileURL)
            }
        }
        return files
    }

    private func aggregate(records: [TokenUsageRecord], date: Date) -> DailyUsageStat {
        guard !records.isEmpty else { return .empty(for: date) }

        var totalCost: Decimal = 0
        var totalTokens = 0

        for record in records {
            totalCost += ModelPricing.cost(for: record)
            totalTokens += record.totalTokens
        }

        // Estimate working time from session timestamps (first to last message per session)
        // Group records by approximate sessions (gaps > 30 min = new session)
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

        // Per-model breakdown
        let modelBreakdown = buildModelBreakdown(records: records, totalTokens: totalTokens)

        // Cache stats
        let cacheStats = buildCacheStats(records: records)

        return DailyUsageStat(
            date: date,
            totalCost: totalCost,
            totalTokens: totalTokens,
            workingTime: workingTime,
            sessionCount: sessionCount,
            modelBreakdown: modelBreakdown,
            cacheStats: cacheStats
        )
    }

    private func buildModelBreakdown(records: [TokenUsageRecord], totalTokens: Int) -> [ModelUsageStat] {
        guard totalTokens > 0 else { return [] }

        // Group by model
        var grouped: [String: (input: Int, output: Int, cost: Decimal)] = [:]
        for record in records {
            let entry = grouped[record.model, default: (input: 0, output: 0, cost: 0)]
            grouped[record.model] = (
                input: entry.input + record.inputTokens,
                output: entry.output + record.outputTokens,
                cost: entry.cost + ModelPricing.cost(for: record)
            )
        }

        return grouped.map { model, data in
            let modelTotal = data.input + data.output
            return ModelUsageStat(
                model: model,
                inputTokens: data.input,
                outputTokens: data.output,
                totalTokens: modelTotal,
                cost: data.cost,
                percentage: Double(modelTotal) / Double(totalTokens) * 100
            )
        }.sorted { $0.totalTokens > $1.totalTokens } // Highest usage first
    }

    private func buildCacheStats(records: [TokenUsageRecord]) -> CacheStats? {
        var totalCacheRead = 0
        var totalCacheCreation = 0
        var totalSavings: Decimal = 0

        for record in records {
            totalCacheRead += record.cacheReadTokens
            totalCacheCreation += record.cacheCreationTokens

            // Savings = cache reads charged at cacheRead rate instead of input rate
            if record.cacheReadTokens > 0 {
                let p = ModelPricing.price(for: record.model)
                let savingsPerToken = p.inputPer1M - p.cacheReadPer1M
                totalSavings += Decimal(record.cacheReadTokens) / 1_000_000 * savingsPerToken
            }
        }

        guard totalCacheRead > 0 || totalCacheCreation > 0 else { return nil }

        return CacheStats(
            cacheReadTokens: totalCacheRead,
            cacheCreationTokens: totalCacheCreation,
            estimatedSavings: totalSavings
        )
    }
}
