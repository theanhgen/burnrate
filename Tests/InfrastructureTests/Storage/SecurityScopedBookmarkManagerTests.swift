import XCTest
@testable import Infrastructure

final class SecurityScopedBookmarkManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: SecurityScopedBookmarkManager!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.bookmark.manager.\(UUID().uuidString)")!
        sut = SecurityScopedBookmarkManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        defaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - hasBookmark

    func test_hasBookmark_returnsFalse_whenNoBookmarkSaved() {
        XCTAssertFalse(sut.hasBookmark(for: BookmarkFolderID.claude))
    }

    func test_hasBookmark_returnsTrue_afterSaving() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        try sut.saveBookmark(for: BookmarkFolderID.claude, url: url)
        XCTAssertTrue(sut.hasBookmark(for: BookmarkFolderID.claude))
    }

    func test_hasBookmark_returnsFalse_afterDeleting() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        try sut.saveBookmark(for: BookmarkFolderID.claude, url: url)
        sut.deleteBookmark(for: BookmarkFolderID.claude)
        XCTAssertFalse(sut.hasBookmark(for: BookmarkFolderID.claude))
    }

    // MARK: - deleteBookmark

    func test_deleteBookmark_noOp_whenNoBookmarkExists() {
        // Should not crash
        sut.deleteBookmark(for: BookmarkFolderID.gemini)
        XCTAssertFalse(sut.hasBookmark(for: BookmarkFolderID.gemini))
    }

    // MARK: - Multiple folders

    func test_differentFolderIDs_areIndependent() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        try sut.saveBookmark(for: BookmarkFolderID.claude, url: url)

        XCTAssertTrue(sut.hasBookmark(for: BookmarkFolderID.claude))
        XCTAssertFalse(sut.hasBookmark(for: BookmarkFolderID.codex))
        XCTAssertFalse(sut.hasBookmark(for: BookmarkFolderID.gemini))
        XCTAssertFalse(sut.hasBookmark(for: BookmarkFolderID.aws))
    }

    // MARK: - resolveBookmark

    func test_resolveBookmark_returnsNil_whenNoBookmarkSaved() {
        XCTAssertNil(sut.resolveBookmark(for: BookmarkFolderID.claude))
    }

    // MARK: - withScopedAccess

    func test_withScopedAccess_throwsNoBookmark_whenNotSaved() {
        XCTAssertThrowsError(try sut.withScopedAccess(folderID: BookmarkFolderID.claude) {
            XCTFail("Should not execute body")
        }) { error in
            XCTAssertEqual(error as? BookmarkError, .noBookmark)
        }
    }

    func test_withScopedAccess_async_throwsNoBookmark_whenNotSaved() async {
        do {
            try await sut.withScopedAccess(folderID: BookmarkFolderID.claude) {
                XCTFail("Should not execute body")
            }
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? BookmarkError, .noBookmark)
        }
    }

    // MARK: - BookmarkFolderID constants

    func test_folderIDConstants() {
        XCTAssertEqual(BookmarkFolderID.claude, "claude")
        XCTAssertEqual(BookmarkFolderID.codex, "codex")
        XCTAssertEqual(BookmarkFolderID.gemini, "gemini")
        XCTAssertEqual(BookmarkFolderID.aws, "aws")
    }

    // MARK: - BookmarkError equatable

    func test_bookmarkErrorEquatable() {
        XCTAssertEqual(BookmarkError.noBookmark, BookmarkError.noBookmark)
        XCTAssertEqual(BookmarkError.staleBookmark, BookmarkError.staleBookmark)
        XCTAssertNotEqual(BookmarkError.noBookmark, BookmarkError.staleBookmark)
        XCTAssertEqual(
            BookmarkError.bookmarkCreationFailed("test"),
            BookmarkError.bookmarkCreationFailed("test")
        )
        XCTAssertNotEqual(
            BookmarkError.bookmarkCreationFailed("a"),
            BookmarkError.bookmarkCreationFailed("b")
        )
    }
}
