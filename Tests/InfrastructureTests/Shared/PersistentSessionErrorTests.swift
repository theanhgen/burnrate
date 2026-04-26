import Testing
import Foundation
@testable import Infrastructure

@Suite("PersistentSession.SessionError Tests")
struct PersistentSessionErrorTests {

    @Test
    func `binaryNotFound error description includes tool name`() {
        let error = PersistentSession.SessionError.binaryNotFound("claude")
        #expect(error.errorDescription?.contains("claude") == true)
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test
    func `launchFailed error description includes reason`() {
        let error = PersistentSession.SessionError.launchFailed("permission denied")
        #expect(error.errorDescription?.contains("permission denied") == true)
    }

    @Test
    func `sessionNotStarted error description`() {
        let error = PersistentSession.SessionError.sessionNotStarted
        #expect(error.errorDescription?.contains("not been started") == true)
    }

    @Test
    func `sessionDied error description`() {
        let error = PersistentSession.SessionError.sessionDied
        #expect(error.errorDescription?.contains("terminated") == true)
    }

    @Test
    func `timedOut error description`() {
        let error = PersistentSession.SessionError.timedOut
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test
    func `invalidOutput error description`() {
        let error = PersistentSession.SessionError.invalidOutput
        #expect(error.errorDescription?.contains("decode") == true)
    }
}
