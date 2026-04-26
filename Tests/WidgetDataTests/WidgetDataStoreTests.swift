import Testing
import Foundation
@testable import WidgetData

@Suite("WidgetDataStore round-trip serialization")
struct WidgetDataStoreTests {

    // MARK: - Codable Round-Trip

    @Test("WidgetProviderSnapshot round-trips through JSON")
    func snapshotRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = WidgetProviderSnapshot(
            providerId: "claude",
            displayName: "Claude",
            capturedAt: now,
            tierBadge: "MAX",
            primaryQuota: WidgetQuota(
                label: "Session",
                percentRemaining: 72.5,
                status: "healthy",
                resetDescription: "Resets in 3h 15m"
            ),
            secondaryQuota: WidgetQuota(
                label: "Weekly",
                percentRemaining: 45,
                status: "warning",
                resetDescription: "Resets in 4d 2h"
            ),
            cost: nil,
            overallStatus: "warning"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode([original])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode([WidgetProviderSnapshot].self, from: data)

        #expect(restored.count == 1)
        let snap = restored[0]
        #expect(snap.providerId == "claude")
        #expect(snap.displayName == "Claude")
        #expect(snap.capturedAt == now)
        #expect(snap.tierBadge == "MAX")
        #expect(snap.primaryQuota?.label == "Session")
        #expect(snap.primaryQuota?.percentRemaining == 72.5)
        #expect(snap.primaryQuota?.status == "healthy")
        #expect(snap.primaryQuota?.resetDescription == "Resets in 3h 15m")
        #expect(snap.secondaryQuota?.label == "Weekly")
        #expect(snap.secondaryQuota?.percentRemaining == 45)
        #expect(snap.overallStatus == "warning")
    }

    @Test("WidgetCost round-trips through JSON")
    func costRoundTrips() throws {
        let original = WidgetProviderSnapshot(
            providerId: "claude",
            displayName: "Claude",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tierBadge: "API",
            primaryQuota: nil,
            secondaryQuota: nil,
            cost: WidgetCost(
                formattedCost: "$12.50",
                formattedBudget: "$100.00",
                percentUsed: 12.5
            ),
            overallStatus: "healthy"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode(WidgetProviderSnapshot.self, from: data)

        #expect(restored.cost?.formattedCost == "$12.50")
        #expect(restored.cost?.formattedBudget == "$100.00")
        #expect(restored.cost?.percentUsed == 12.5)
    }

    @Test("Empty array round-trips")
    func emptyArrayRoundTrips() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode([WidgetProviderSnapshot]())

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode([WidgetProviderSnapshot].self, from: data)

        #expect(restored.isEmpty)
    }

    @Test("Snapshot with nil optional fields round-trips")
    func nilFieldsRoundTrip() throws {
        let original = WidgetProviderSnapshot(
            providerId: "gemini",
            displayName: "Gemini",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tierBadge: nil,
            primaryQuota: WidgetQuota(
                label: "Usage",
                percentRemaining: 90,
                status: "healthy",
                resetDescription: nil
            ),
            secondaryQuota: nil,
            cost: nil,
            overallStatus: "healthy"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode(WidgetProviderSnapshot.self, from: data)

        #expect(restored.tierBadge == nil)
        #expect(restored.primaryQuota?.resetDescription == nil)
        #expect(restored.secondaryQuota == nil)
        #expect(restored.cost == nil)
    }

    // MARK: - File System Round-Trip

    @Test("WidgetDataStore writes and reads snapshots via file system")
    func fileSystemRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetDataStoreTests-\(UUID().uuidString)")
        let fileURL = tempDir.appendingPathComponent("widget-snapshots.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = WidgetDataStore(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshots = [
            WidgetProviderSnapshot(
                providerId: "claude",
                displayName: "Claude",
                capturedAt: now,
                tierBadge: "MAX",
                primaryQuota: WidgetQuota(label: "Session", percentRemaining: 72.5, status: "healthy", resetDescription: "Resets in 3h"),
                secondaryQuota: nil,
                cost: nil,
                overallStatus: "healthy"
            ),
            WidgetProviderSnapshot(
                providerId: "codex",
                displayName: "Codex",
                capturedAt: now,
                tierBadge: nil,
                primaryQuota: WidgetQuota(label: "Session", percentRemaining: 10, status: "critical", resetDescription: nil),
                secondaryQuota: nil,
                cost: WidgetCost(formattedCost: "$5.00", formattedBudget: "$50.00", percentUsed: 10),
                overallStatus: "critical"
            ),
        ]

        store.write(snapshots)
        let restored = store.read()

        #expect(restored.count == 2)
        #expect(restored[0].providerId == "claude")
        #expect(restored[0].primaryQuota?.percentRemaining == 72.5)
        #expect(restored[1].providerId == "codex")
        #expect(restored[1].cost?.formattedCost == "$5.00")
    }

    @Test("WidgetDataStore creates directory if missing")
    func createsDirectoryIfMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetDataStoreTests-\(UUID().uuidString)")
            .appendingPathComponent("nested")
        let fileURL = tempDir.appendingPathComponent("widget-snapshots.json")
        defer { try? FileManager.default.removeItem(at: tempDir.deletingLastPathComponent()) }

        let store = WidgetDataStore(fileURL: fileURL)
        store.write([
            WidgetProviderSnapshot(
                providerId: "gemini",
                displayName: "Gemini",
                capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                tierBadge: nil,
                primaryQuota: nil,
                secondaryQuota: nil,
                cost: nil,
                overallStatus: "healthy"
            ),
        ])

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let restored = store.read()
        #expect(restored.count == 1)
        #expect(restored[0].providerId == "gemini")
    }

    @Test("WidgetDataStore read returns empty array when file missing")
    func readReturnsEmptyWhenFileMissing() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let store = WidgetDataStore(fileURL: fileURL)

        #expect(store.read().isEmpty)
    }

    @Test("Multiple providers round-trip preserving order")
    func multipleProvidersRoundTrip() throws {
        let snapshots = [
            WidgetProviderSnapshot(
                providerId: "claude",
                displayName: "Claude",
                capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                tierBadge: "MAX",
                primaryQuota: WidgetQuota(label: "Session", percentRemaining: 72.5, status: "healthy", resetDescription: nil),
                secondaryQuota: nil,
                cost: nil,
                overallStatus: "healthy"
            ),
            WidgetProviderSnapshot(
                providerId: "codex",
                displayName: "Codex",
                capturedAt: Date(timeIntervalSince1970: 1_700_000_100),
                tierBadge: nil,
                primaryQuota: WidgetQuota(label: "Session", percentRemaining: 10, status: "critical", resetDescription: nil),
                secondaryQuota: nil,
                cost: nil,
                overallStatus: "critical"
            ),
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(snapshots)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let restored = try decoder.decode([WidgetProviderSnapshot].self, from: data)

        #expect(restored.count == 2)
        #expect(restored[0].providerId == "claude")
        #expect(restored[1].providerId == "codex")
        #expect(restored[1].overallStatus == "critical")
    }
}
