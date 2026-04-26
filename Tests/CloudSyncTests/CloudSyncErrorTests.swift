import Testing
import Foundation
@testable import CloudSync

@Suite("CloudSyncError Tests")
struct CloudSyncErrorTests {

    @Test
    func `invalidRecord is an Error`() {
        let error: Error = CloudSyncError.invalidRecord
        #expect(error is CloudSyncError)
    }

    @Test
    func `zoneCreationFailed wraps underlying error`() {
        let underlying = NSError(domain: "CKErrorDomain", code: 1)
        let error = CloudSyncError.zoneCreationFailed(underlying: underlying)

        if case .zoneCreationFailed(let wrapped) = error {
            #expect((wrapped as NSError).domain == "CKErrorDomain")
        } else {
            Issue.record("Expected zoneCreationFailed")
        }
    }

    @Test
    func `saveFailed wraps underlying error`() {
        let underlying = NSError(domain: "CKErrorDomain", code: 2)
        let error = CloudSyncError.saveFailed(underlying: underlying)

        if case .saveFailed(let wrapped) = error {
            #expect((wrapped as NSError).code == 2)
        } else {
            Issue.record("Expected saveFailed")
        }
    }

    @Test
    func `fetchFailed wraps underlying error`() {
        let underlying = NSError(domain: "CKErrorDomain", code: 3)
        let error = CloudSyncError.fetchFailed(underlying: underlying)

        if case .fetchFailed(let wrapped) = error {
            #expect((wrapped as NSError).code == 3)
        } else {
            Issue.record("Expected fetchFailed")
        }
    }

    @Test
    func `noAccount case exists`() {
        let error = CloudSyncError.noAccount
        if case .noAccount = error {
            // pass
        } else {
            Issue.record("Expected noAccount")
        }
    }
}
