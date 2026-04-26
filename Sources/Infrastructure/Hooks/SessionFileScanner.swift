import Foundation
import Domain

/// Scans ~/.claude/sessions/*.json to detect active Claude Code sessions.
/// Terminal-agnostic: works with any terminal app (Ghostty, Terminal.app, iTerm2, etc.).
/// Polls on a timer and emits SessionEvents by diffing against previous state.
public final class SessionFileScanner: @unchecked Sendable {
    private let sessionsDirectory: String
    private let interval: TimeInterval
    private var timer: DispatchSourceTimer?
    private var continuation: AsyncStream<SessionEvent>.Continuation?
    private var knownSessions: [Int: ScannedSession] = [:] // PID -> session

    private let queue = DispatchQueue(label: "com.nguyentheanh.burnrate.sessionscanner")

    public init(
        sessionsDirectory: String? = nil,
        interval: TimeInterval = 5
    ) {
        self.sessionsDirectory = sessionsDirectory ?? {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/.claude/sessions"
        }()
        self.interval = interval
    }

    /// Starts scanning and returns a stream of session events.
    public func start() -> AsyncStream<SessionEvent> {
        let stream = AsyncStream<SessionEvent> { continuation in
            self.queue.async {
                self.continuation = continuation
            }
            continuation.onTermination = { _ in
                self.stop()
            }
        }

        queue.async {
            // Initial scan
            self.scan()

            // Set up periodic timer
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.interval, repeating: self.interval)
            timer.setEventHandler { [weak self] in
                self?.scan()
            }
            timer.resume()
            self.timer = timer
        }

        return stream
    }

    /// Stops scanning and cleans up.
    public func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            continuation?.finish()
            continuation = nil
            knownSessions.removeAll()
        }
    }

    // MARK: - Scanning (runs on queue)

    private func scan() {
        let currentSessions = readSessionFiles()

        // Detect new sessions (present in files, not in known)
        for (pid, session) in currentSessions where knownSessions[pid] == nil {
            knownSessions[pid] = session
            continuation?.yield(SessionEvent(
                sessionId: session.sessionId,
                eventName: .sessionStart,
                cwd: session.cwd,
                name: session.name
            ))
            AppLog.hooks.info("Scanner detected session start: \(session.sessionId) in \((session.cwd as NSString).lastPathComponent)")
        }

        // Detect ended sessions (present in known, missing or PID dead)
        for (pid, session) in knownSessions {
            let stillExists = currentSessions[pid] != nil
            if !stillExists {
                knownSessions.removeValue(forKey: pid)
                continuation?.yield(SessionEvent(
                    sessionId: session.sessionId,
                    eventName: .sessionEnd,
                    cwd: session.cwd
                ))
                AppLog.hooks.info("Scanner detected session end: \(session.sessionId)")
            }
        }
    }

    /// Reads session files and filters to those with alive PIDs.
    private func readSessionFiles() -> [Int: ScannedSession] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: sessionsDirectory) else {
            return [:]
        }

        var result: [Int: ScannedSession] = [:]
        for file in files where file.hasSuffix(".json") {
            let pidString = (file as NSString).deletingPathExtension
            guard let pid = Int(pidString) else { continue }

            // Check if process is still alive
            guard kill(pid_t(pid), 0) == 0 else { continue }

            let path = "\(sessionsDirectory)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let session = ScannedSession.parse(data, pid: pid) else { continue }

            result[pid] = session
        }
        return result
    }
}

// MARK: - ScannedSession

/// Lightweight representation of a Claude Code session file.
struct ScannedSession: Sendable {
    let pid: Int
    let sessionId: String
    let cwd: String
    let startedAt: TimeInterval // milliseconds since epoch
    let kind: String
    let entrypoint: String
    let name: String?

    static func parse(_ data: Data, pid: Int) -> ScannedSession? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionId = json["sessionId"] as? String,
              let cwd = json["cwd"] as? String else {
            return nil
        }

        return ScannedSession(
            pid: pid,
            sessionId: sessionId,
            cwd: cwd,
            startedAt: json["startedAt"] as? TimeInterval ?? 0,
            kind: json["kind"] as? String ?? "unknown",
            entrypoint: json["entrypoint"] as? String ?? "unknown",
            name: json["name"] as? String
        )
    }
}
