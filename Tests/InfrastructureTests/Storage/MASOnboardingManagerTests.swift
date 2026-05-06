import XCTest
@testable import Infrastructure

final class MASOnboardingManagerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var bookmarks: FakeBookmarkManager!
    private var sut: MASOnboardingManager!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.mas.onboarding.\(UUID().uuidString)")!
        bookmarks = FakeBookmarkManager()
        sut = MASOnboardingManager(defaults: defaults, bookmarkManager: bookmarks)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        defaults = nil
        bookmarks = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - shouldShowOnboarding

    func test_shouldShowOnboarding_trueOnFirstLaunch() {
        XCTAssertTrue(sut.shouldShowOnboarding)
    }

    func test_shouldShowOnboarding_falseAfterMarkComplete_withNoGrants() {
        sut.markComplete()
        XCTAssertFalse(sut.shouldShowOnboarding)
    }

    func test_shouldShowOnboarding_falseAfterMarkComplete_withValidGrant() {
        bookmarks.grant(BookmarkFolderID.claude, url: URL(fileURLWithPath: "/tmp"))
        sut.markComplete()
        XCTAssertFalse(sut.shouldShowOnboarding)
    }

    func test_shouldShowOnboarding_trueWhenGrantedFolderLostAccess() {
        bookmarks.grant(BookmarkFolderID.claude, url: URL(fileURLWithPath: "/tmp"))
        sut.markComplete()

        bookmarks.simulateLostAccess(BookmarkFolderID.claude)

        XCTAssertTrue(sut.shouldShowOnboarding)
    }

    func test_shouldShowOnboarding_falseWhenNeverGrantedFolderHasNoBookmark() {
        // User completed onboarding but skipped Gemini — should NOT re-show
        sut.markComplete()
        // Gemini never bookmarked: hasBookmark returns false → ignored by hasLostAccess
        XCTAssertFalse(sut.shouldShowOnboarding)
    }

    func test_shouldShowOnboarding_falseWhenSomeFoldersGrantedAndAllResolve() {
        bookmarks.grant(BookmarkFolderID.claude, url: URL(fileURLWithPath: "/tmp"))
        bookmarks.grant(BookmarkFolderID.gemini, url: URL(fileURLWithPath: "/tmp"))
        sut.markComplete()
        XCTAssertFalse(sut.shouldShowOnboarding)
    }

    func test_shouldShowOnboarding_trueWhenOneOfMultipleGrantedFoldersLosesAccess() {
        bookmarks.grant(BookmarkFolderID.claude, url: URL(fileURLWithPath: "/tmp"))
        bookmarks.grant(BookmarkFolderID.gemini, url: URL(fileURLWithPath: "/tmp"))
        sut.markComplete()

        bookmarks.simulateLostAccess(BookmarkFolderID.gemini)

        XCTAssertTrue(sut.shouldShowOnboarding)
    }

    // MARK: - reset

    func test_reset_clearsCompletedState() {
        sut.markComplete()
        XCTAssertFalse(sut.shouldShowOnboarding)

        sut.reset()
        XCTAssertTrue(sut.shouldShowOnboarding)
    }

    // MARK: - grantedFolderIDs

    func test_grantedFolderIDs_emptyWhenNoneGranted() {
        XCTAssertTrue(sut.grantedFolderIDs().isEmpty)
    }

    func test_grantedFolderIDs_containsBookmarkedFolders() {
        bookmarks.grant(BookmarkFolderID.claude, url: URL(fileURLWithPath: "/tmp"))
        bookmarks.grant(BookmarkFolderID.gemini, url: URL(fileURLWithPath: "/tmp"))

        let granted = sut.grantedFolderIDs()
        XCTAssertTrue(granted.contains(BookmarkFolderID.claude))
        XCTAssertTrue(granted.contains(BookmarkFolderID.gemini))
        XCTAssertFalse(granted.contains(BookmarkFolderID.codex))
    }

    func test_grantedFolderIDs_excludesRequiredFoldersNotInRequiredSet() {
        // AWS is not in requiredFolderIDs
        bookmarks.grant(BookmarkFolderID.aws, url: URL(fileURLWithPath: "/tmp"))
        XCTAssertFalse(sut.grantedFolderIDs().contains(BookmarkFolderID.aws))
    }

    // MARK: - hasCompletedOnboarding

    func test_hasCompletedOnboarding_falseInitially() {
        XCTAssertFalse(sut.hasCompletedOnboarding)
    }

    func test_hasCompletedOnboarding_trueAfterMarkComplete() {
        sut.markComplete()
        XCTAssertTrue(sut.hasCompletedOnboarding)
    }
}

// MARK: - Test Double

private final class FakeBookmarkManager: BookmarkManaging, @unchecked Sendable {
    private var recordedIDs: Set<String> = []
    private var resolvableURLs: [String: URL] = [:]

    func grant(_ folderID: String, url: URL) {
        recordedIDs.insert(folderID)
        resolvableURLs[folderID] = url
    }

    func simulateLostAccess(_ folderID: String) {
        // Keep the record (hasBookmark true) but remove the resolvable URL
        resolvableURLs.removeValue(forKey: folderID)
    }

    // MARK: - BookmarkManaging

    func hasBookmark(for folderID: String) -> Bool {
        recordedIDs.contains(folderID)
    }

    func resolveBookmark(for folderID: String) -> URL? {
        resolvableURLs[folderID]
    }

    func saveBookmark(for folderID: String, url: URL) throws {
        grant(folderID, url: url)
    }

    func deleteBookmark(for folderID: String) {
        recordedIDs.remove(folderID)
        resolvableURLs.removeValue(forKey: folderID)
    }

    func withScopedAccess<T: Sendable>(folderID: String, body: @Sendable () throws -> T) throws -> T {
        try body()
    }

    func withScopedAccess<T: Sendable>(folderID: String, body: @Sendable () async throws -> T) async throws -> T {
        try await body()
    }
}
