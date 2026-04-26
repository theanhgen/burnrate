import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("CursorUsageProbe Behavior Tests")
struct CursorUsageProbeTests {

    // MARK: - JWT Extraction Tests

    @Test
    func `extractUserIdFromJWT with valid token`() throws {
        // Create a valid JWT with sub claim
        // Header: {"alg":"HS256","typ":"JWT"}
        // Payload: {"sub":"user_12345","exp":9999999999}
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = base64url(json: ["sub": "user_12345", "exp": 9999999999])
        let token = "\(header).\(payload).signature"

        let userId = try CursorUsageProbe.extractUserIdFromJWT(token)
        #expect(userId == "user_12345")
    }

    @Test
    func `extractUserIdFromJWT throws for malformed token`() {
        #expect(throws: ProbeError.self) {
            try CursorUsageProbe.extractUserIdFromJWT("not-a-jwt")
        }
    }

    @Test
    func `extractUserIdFromJWT throws for missing sub claim`() {
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = base64url(json: ["exp": 9999999999])
        let token = "\(header).\(payload).signature"

        #expect(throws: ProbeError.self) {
            try CursorUsageProbe.extractUserIdFromJWT(token)
        }
    }

    @Test
    func `extractUserIdFromJWT throws for empty sub claim`() {
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = base64url(json: ["sub": ""])
        let token = "\(header).\(payload).signature"

        #expect(throws: ProbeError.self) {
            try CursorUsageProbe.extractUserIdFromJWT(token)
        }
    }

    @Test
    func `extractUserIdFromJWT handles base64url padding`() throws {
        // Create a token with a payload that needs padding
        let header = "eyJhbGciOiJIUzI1NiJ9"
        let payload = base64url(json: ["sub": "u"])
        let token = "\(header).\(payload).sig"

        let userId = try CursorUsageProbe.extractUserIdFromJWT(token)
        #expect(userId == "u")
    }

    // MARK: - isAvailable Tests

    @Test
    func `isAvailable returns false when database does not exist`() async {
        let probe = CursorUsageProbe(dbPathOverride: "/nonexistent/path/state.vscdb")
        #expect(await probe.isAvailable() == false)
    }

    // MARK: - Probe Error Tests

    @Test
    func `probe throws cliNotFound when database missing`() async {
        let probe = CursorUsageProbe(dbPathOverride: "/nonexistent/path/state.vscdb")

        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }

    // MARK: - Helpers

    private func base64url(json: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
