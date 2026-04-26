import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct SessionFileScannerTests {
    /// Creates a temp directory with session files for testing.
    private func makeTempSessionsDir() throws -> String {
        let dir = NSTemporaryDirectory() + "burnrate-test-sessions-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeSessionFile(dir: String, pid: Int, sessionId: String, cwd: String) throws {
        let json: [String: Any] = [
            "pid": pid,
            "sessionId": sessionId,
            "cwd": cwd,
            "startedAt": Int(Date().timeIntervalSince1970 * 1000),
            "kind": "interactive",
            "entrypoint": "cli",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: "\(dir)/\(pid).json"))
    }

    private func removeSessionFile(dir: String, pid: Int) {
        try? FileManager.default.removeItem(atPath: "\(dir)/\(pid).json")
    }

    private func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    // MARK: - ScannedSession Parsing

    @Test
    func `parses valid session JSON`() throws {
        let json: [String: Any] = [
            "pid": 12345,
            "sessionId": "abc-123",
            "cwd": "/Users/test/project",
            "startedAt": 1775500969209,
            "kind": "interactive",
            "entrypoint": "cli",
            "name": "my-session",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let session = ScannedSession.parse(data, pid: 12345)

        #expect(session != nil)
        #expect(session?.sessionId == "abc-123")
        #expect(session?.cwd == "/Users/test/project")
        #expect(session?.name == "my-session")
        #expect(session?.kind == "interactive")
        #expect(session?.entrypoint == "cli")
    }

    @Test
    func `returns nil for invalid JSON`() {
        let data = "not json".data(using: .utf8)!
        #expect(ScannedSession.parse(data, pid: 1) == nil)
    }

    @Test
    func `returns nil for missing required fields`() throws {
        let json: [String: Any] = ["pid": 1, "cwd": "/tmp"]
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(ScannedSession.parse(data, pid: 1) == nil) // missing sessionId
    }

    @Test
    func `handles optional name field`() throws {
        let json: [String: Any] = [
            "pid": 1,
            "sessionId": "abc",
            "cwd": "/tmp",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let session = ScannedSession.parse(data, pid: 1)

        #expect(session != nil)
        #expect(session?.name == nil)
    }

    // MARK: - Scanner Lifecycle

    @Test
    func `scanner detects sessions from files with alive PIDs`() async throws {
        let dir = try makeTempSessionsDir()
        defer { cleanup(dir) }

        // Use current process PID (guaranteed alive)
        let myPid = Int(ProcessInfo.processInfo.processIdentifier)
        try writeSessionFile(dir: dir, pid: myPid, sessionId: "live-session", cwd: "/tmp/project")

        // Also write a dead PID session (PID 1 is launchd, but PID 99999999 shouldn't exist)
        try writeSessionFile(dir: dir, pid: 99999999, sessionId: "dead-session", cwd: "/tmp/dead")

        let scanner = SessionFileScanner(sessionsDirectory: dir, interval: 0.1)
        let events = scanner.start()

        // Collect first event
        var received: [SessionEvent] = []
        for await event in events {
            received.append(event)
            if received.count >= 1 { break }
        }
        scanner.stop()

        // Should only get the live session
        #expect(received.count == 1)
        #expect(received.first?.sessionId == "live-session")
        #expect(received.first?.eventName == .sessionStart)
    }

    @Test
    func `scanner emits end event when session file is removed`() async throws {
        let dir = try makeTempSessionsDir()
        defer { cleanup(dir) }

        let myPid = Int(ProcessInfo.processInfo.processIdentifier)
        try writeSessionFile(dir: dir, pid: myPid, sessionId: "temp-session", cwd: "/tmp/project")

        let scanner = SessionFileScanner(sessionsDirectory: dir, interval: 0.2)
        let events = scanner.start()

        var received: [SessionEvent] = []
        for await event in events {
            received.append(event)
            if event.eventName == .sessionStart {
                // Remove the file after detecting start
                removeSessionFile(dir: dir, pid: myPid)
            }
            if event.eventName == .sessionEnd { break }
        }
        scanner.stop()

        #expect(received.count == 2)
        #expect(received[0].eventName == .sessionStart)
        #expect(received[1].eventName == .sessionEnd)
        #expect(received[1].sessionId == "temp-session")
    }

    @Test
    func `scanner handles empty directory`() async throws {
        let dir = try makeTempSessionsDir()
        defer { cleanup(dir) }

        let scanner = SessionFileScanner(sessionsDirectory: dir, interval: 0.1)
        let events = scanner.start()

        // Write a session after scanner starts
        let myPid = Int(ProcessInfo.processInfo.processIdentifier)
        try writeSessionFile(dir: dir, pid: myPid, sessionId: "late-session", cwd: "/tmp/project")

        var received: [SessionEvent] = []
        for await event in events {
            received.append(event)
            if received.count >= 1 { break }
        }
        scanner.stop()

        #expect(received.first?.sessionId == "late-session")
    }

    @Test
    func `scanner handles non-existent directory`() async throws {
        let scanner = SessionFileScanner(sessionsDirectory: "/tmp/nonexistent-\(UUID().uuidString)", interval: 0.1)
        let events = scanner.start()

        // Should produce no events, not crash
        // Stop after a brief moment
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            scanner.stop()
        }

        var count = 0
        for await _ in events {
            count += 1
        }
        #expect(count == 0)
    }
}
