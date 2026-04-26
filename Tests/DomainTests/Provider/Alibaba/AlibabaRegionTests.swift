import Testing
import Foundation
@testable import Domain

@Suite("AlibabaRegion Tests")
struct AlibabaRegionTests {

    // MARK: - Raw Value Tests

    @Test
    func `international has correct raw value`() {
        #expect(AlibabaRegion.international.rawValue == "intl")
    }

    @Test
    func `china mainland has correct raw value`() {
        #expect(AlibabaRegion.chinaMainland.rawValue == "cn")
    }

    // MARK: - Display Name Tests

    @Test
    func `international display name`() {
        #expect(AlibabaRegion.international.displayName == "International")
    }

    @Test
    func `china mainland display name`() {
        #expect(AlibabaRegion.chinaMainland.displayName == "China Mainland")
    }

    // MARK: - CaseIterable Tests

    @Test
    func `all cases contains both regions`() {
        #expect(AlibabaRegion.allCases.count == 2)
        #expect(AlibabaRegion.allCases.contains(.international))
        #expect(AlibabaRegion.allCases.contains(.chinaMainland))
    }
}

@Suite("AlibabaCookieSource Tests")
struct AlibabaCookieSourceTests {

    @Test
    func `auto has correct raw value`() {
        #expect(AlibabaCookieSource.auto.rawValue == "auto")
    }

    @Test
    func `manual has correct raw value`() {
        #expect(AlibabaCookieSource.manual.rawValue == "manual")
    }

    @Test
    func `auto display name`() {
        #expect(AlibabaCookieSource.auto.displayName == "Auto (from browser)")
    }

    @Test
    func `manual display name`() {
        #expect(AlibabaCookieSource.manual.displayName == "Manual")
    }

    @Test
    func `all cases contains both sources`() {
        #expect(AlibabaCookieSource.allCases.count == 2)
    }
}
