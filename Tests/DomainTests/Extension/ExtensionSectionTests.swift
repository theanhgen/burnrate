import Testing
import Foundation
@testable import Domain

@Suite("ExtensionSection Tests")
struct ExtensionSectionTests {

    // MARK: - Script Init Tests

    @Test
    func `init with probe command creates script config`() {
        let section = ExtensionSection(
            id: "test-section",
            type: .quotaGrid,
            probeCommand: "echo hello"
        )

        #expect(section.id == "test-section")
        #expect(section.type == .quotaGrid)
        #expect(section.probeConfig == .script("echo hello"))
        #expect(section.probeCommand == "echo hello")
    }

    @Test
    func `init with probe command uses default intervals`() {
        let section = ExtensionSection(
            id: "test",
            type: .statusBanner,
            probeCommand: "test"
        )

        #expect(section.refreshInterval == 60)
        #expect(section.timeout == 10)
    }

    @Test
    func `init with custom intervals`() {
        let section = ExtensionSection(
            id: "test",
            type: .metricsRow,
            probeCommand: "test",
            refreshInterval: 120,
            timeout: 30
        )

        #expect(section.refreshInterval == 120)
        #expect(section.timeout == 30)
    }

    // MARK: - ProbeConfig Init Tests

    @Test
    func `init with healthCheck probe config`() {
        let url = URL(string: "https://example.com/health")!
        let section = ExtensionSection(
            id: "health",
            type: .healthCheck,
            probeConfig: .healthCheck(url: url)
        )

        #expect(section.probeConfig == .healthCheck(url: url))
        #expect(section.probeCommand == "")
    }

    @Test
    func `init with script probe config`() {
        let section = ExtensionSection(
            id: "script",
            type: .costUsage,
            probeConfig: .script("/usr/bin/my-probe")
        )

        #expect(section.probeCommand == "/usr/bin/my-probe")
    }

    // MARK: - SectionType Tests

    @Test
    func `section type raw values`() {
        #expect(SectionType.quotaGrid.rawValue == "quotaGrid")
        #expect(SectionType.costUsage.rawValue == "costUsage")
        #expect(SectionType.dailyUsage.rawValue == "dailyUsage")
        #expect(SectionType.metricsRow.rawValue == "metricsRow")
        #expect(SectionType.statusBanner.rawValue == "statusBanner")
        #expect(SectionType.healthCheck.rawValue == "healthCheck")
    }

    // MARK: - Equatable Tests

    @Test
    func `sections with same values are equal`() {
        let section1 = ExtensionSection(id: "a", type: .quotaGrid, probeCommand: "cmd")
        let section2 = ExtensionSection(id: "a", type: .quotaGrid, probeCommand: "cmd")
        #expect(section1 == section2)
    }

    @Test
    func `sections with different ids are not equal`() {
        let section1 = ExtensionSection(id: "a", type: .quotaGrid, probeCommand: "cmd")
        let section2 = ExtensionSection(id: "b", type: .quotaGrid, probeCommand: "cmd")
        #expect(section1 != section2)
    }
}
