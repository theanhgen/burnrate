import Testing
import Foundation
@testable import Domain

@Suite
struct SnapshotFormatterTests {

    // MARK: - Test Fixtures

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private static let resetDate = Date(timeIntervalSince1970: 1_700_010_000)

    private static func makeSnapshot(
        providers: [ExportableProvider] = [sampleProvider],
        appVersion: String = "0.4.57"
    ) -> ExportableSnapshot {
        ExportableSnapshot(
            exportedAt: fixedDate,
            appVersion: appVersion,
            providers: providers
        )
    }

    private static var sampleProvider: ExportableProvider {
        ExportableProvider(
            id: "claude",
            name: "Claude",
            status: "warning",
            accountEmail: "test@example.com",
            accountTier: "Claude Max",
            quotas: [
                ExportableQuota(
                    type: "Session",
                    percentRemaining: 42.5,
                    percentUsed: 57.5,
                    status: "warning",
                    resetsAt: resetDate,
                    resetDescription: "Resets in 2h 47m",
                    pace: "ahead",
                    burnRate: 1.8
                ),
                ExportableQuota(
                    type: "Weekly",
                    percentRemaining: 68.0,
                    percentUsed: 32.0,
                    status: "healthy",
                    resetsAt: nil,
                    resetDescription: nil,
                    pace: "behind",
                    burnRate: 0.6
                ),
            ],
            costUsage: ExportableCostUsage(
                totalCost: "$12.50",
                budget: "$100.00",
                budgetPercentUsed: 12.5,
                apiDuration: "6m 19.7s",
                wallDuration: "2h 15m 0.0s",
                linesAdded: 450,
                linesRemoved: 120,
                resetsAt: nil
            ),
            dailyUsage: ExportableDailyUsage(
                todayCost: "$5.30",
                todayTokens: "2.1M",
                todayWorkingTime: "3h 45m",
                todaySessions: 4,
                previousCost: "$8.20",
                previousTokens: "3.5M",
                costDelta: "-$2.90",
                tokenDelta: "-1.4M",
                timeDelta: "-1h 10m"
            )
        )
    }

    private static var minimalProvider: ExportableProvider {
        ExportableProvider(
            id: "codex",
            name: "Codex",
            status: "healthy",
            quotas: [
                ExportableQuota(
                    type: "Session",
                    percentRemaining: 90.0,
                    percentUsed: 10.0,
                    status: "healthy"
                ),
            ]
        )
    }

    // MARK: - JSON Tests

    @Suite struct JSONTests {
        @Test
        func `includes metadata and provider data`() {
            let json = SnapshotFormatter.json(makeSnapshot())
            #expect(json.contains("\"appVersion\" : \"0.4.57\""))
            #expect(json.contains("\"exportedAt\""))
            #expect(json.contains("\"claude\""))
            #expect(json.contains("\"warning\""))
        }

        @Test
        func `includes quota details`() {
            let json = SnapshotFormatter.json(makeSnapshot())
            #expect(json.contains("\"percentRemaining\" : 42.5"))
            #expect(json.contains("\"burnRate\" : 1.8"))
            #expect(json.contains("\"pace\" : \"ahead\""))
        }

        @Test
        func `includes cost usage`() {
            let json = SnapshotFormatter.json(makeSnapshot())
            #expect(json.contains("\"totalCost\" : \"$12.50\""))
            #expect(json.contains("\"linesAdded\" : 450"))
        }

        @Test
        func `includes daily usage`() {
            let json = SnapshotFormatter.json(makeSnapshot())
            #expect(json.contains("\"todayCost\" : \"$5.30\"") || json.contains("\"cost\" : \"$5.30\""))
            #expect(json.contains("\"sessions\" : 4"))
        }

        @Test
        func `empty providers returns valid JSON`() {
            let snapshot = makeSnapshot(providers: [])
            let json = SnapshotFormatter.json(snapshot)
            #expect(json.contains("\"providers\" : ["))
            #expect(json.contains("\"appVersion\""))
        }
    }

    // MARK: - CSV Tests

    @Suite struct CSVTests {
        @Test
        func `header row contains all columns`() {
            let csv = SnapshotFormatter.csv(makeSnapshot())
            let header = csv.split(separator: "\n").first!
            #expect(header.contains("timestamp"))
            #expect(header.contains("provider"))
            #expect(header.contains("quota_type"))
            #expect(header.contains("percent_remaining"))
            #expect(header.contains("burn_rate"))
            #expect(header.contains("cost_total"))
        }

        @Test
        func `one row per quota`() {
            let csv = SnapshotFormatter.csv(makeSnapshot())
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
            // header + 2 quotas (session + weekly) + trailing empty
            #expect(lines.count == 4)
        }

        @Test
        func `escapes provider names with commas`() {
            let provider = ExportableProvider(
                id: "test",
                name: "Provider, Inc.",
                status: "healthy",
                quotas: [
                    ExportableQuota(type: "Session", percentRemaining: 80, percentUsed: 20, status: "healthy"),
                ]
            )
            let csv = SnapshotFormatter.csv(makeSnapshot(providers: [provider]))
            #expect(csv.contains("\"Provider, Inc.\""))
        }

        @Test
        func `includes burn rate values`() {
            let csv = SnapshotFormatter.csv(makeSnapshot())
            #expect(csv.contains("1.80"))
            #expect(csv.contains("0.60"))
        }

        @Test
        func `cost-only provider emits a row`() {
            let provider = ExportableProvider(
                id: "api",
                name: "Claude API",
                status: "healthy",
                costUsage: ExportableCostUsage(
                    totalCost: "$50.00",
                    apiDuration: "1h 0m 0.0s",
                    wallDuration: "2h 0m 0.0s",
                    linesAdded: 0,
                    linesRemoved: 0
                )
            )
            let csv = SnapshotFormatter.csv(makeSnapshot(providers: [provider]))
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
            #expect(lines.count == 3) // header + 1 row + trailing empty
            #expect(csv.contains("$50.00"))
        }

        @Test
        func `empty providers produces header only`() {
            let csv = SnapshotFormatter.csv(makeSnapshot(providers: []))
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
            #expect(lines.count == 1)
        }
    }

    // MARK: - Markdown Tests

    @Suite struct MarkdownTests {
        @Test
        func `includes header with timestamp`() {
            let md = SnapshotFormatter.markdown(makeSnapshot())
            #expect(md.hasPrefix("## burnrate Snapshot ("))
        }

        @Test
        func `includes summary table`() {
            let md = SnapshotFormatter.markdown(makeSnapshot())
            #expect(md.contains("| Provider | Status | Quotas | Resets |"))
            #expect(md.contains("| Claude |"))
            #expect(md.contains("42% left"))
        }

        @Test
        func `includes cost section`() {
            let md = SnapshotFormatter.markdown(makeSnapshot())
            #expect(md.contains("### Cost Usage"))
            #expect(md.contains("$12.50 spent"))
            #expect(md.contains("+450 / -120 lines"))
        }

        @Test
        func `includes daily usage section`() {
            let md = SnapshotFormatter.markdown(makeSnapshot())
            #expect(md.contains("### Daily Usage"))
            #expect(md.contains("$5.30"))
            #expect(md.contains("4 sessions"))
        }

        @Test
        func `includes footer with version`() {
            let md = SnapshotFormatter.markdown(makeSnapshot())
            #expect(md.contains("burnrate v0.4.57"))
        }

        @Test
        func `status emoji mapping`() {
            let providers = [
                ExportableProvider(id: "a", name: "Healthy", status: "healthy"),
                ExportableProvider(id: "b", name: "Warning", status: "warning"),
                ExportableProvider(id: "c", name: "Critical", status: "critical"),
                ExportableProvider(id: "d", name: "Depleted", status: "depleted"),
            ]
            let md = SnapshotFormatter.markdown(makeSnapshot(providers: providers))
            #expect(md.contains("✅"))
            #expect(md.contains("⚠️"))
            #expect(md.contains("🔴"))
            #expect(md.contains("⛔"))
        }
    }

    // MARK: - Format Dispatch

    @Test
    func `format dispatches to correct formatter`() {
        let snapshot = makeSnapshot()
        let json = SnapshotFormatter.format(snapshot, as: .json)
        let csv = SnapshotFormatter.format(snapshot, as: .csv)
        let md = SnapshotFormatter.format(snapshot, as: .markdown)

        #expect(json.contains("{"))
        #expect(csv.contains("timestamp,"))
        #expect(md.contains("## burnrate"))
    }

    // MARK: - Multiple Providers

    @Test
    func `handles multiple providers`() {
        let snapshot = makeSnapshot(providers: [sampleProvider, minimalProvider])

        let json = SnapshotFormatter.json(snapshot)
        #expect(json.contains("claude"))
        #expect(json.contains("codex"))

        let csv = SnapshotFormatter.csv(snapshot)
        let dataLines = csv.split(separator: "\n", omittingEmptySubsequences: true).dropFirst()
        #expect(dataLines.count == 3) // 2 claude quotas + 1 codex quota

        let md = SnapshotFormatter.markdown(snapshot)
        #expect(md.contains("Claude"))
        #expect(md.contains("Codex"))
    }
}
