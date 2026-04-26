import Foundation
import Observation

/// Monitors Claude Code sessions by processing hook events and file scanner events.
/// Single source of truth for session state, similar to QuotaMonitor for providers.
/// Supports multiple concurrent active sessions (common with multiple terminal tabs).
/// Isolated to @MainActor since it's consumed by SwiftUI views.
@MainActor
@Observable
public final class SessionMonitor {
    /// All currently active sessions (keyed by session ID)
    public private(set) var activeSessions: [ClaudeSession] = []

    /// Recently completed sessions (most recent first)
    public private(set) var recentSessions: [ClaudeSession] = []

    /// Maximum number of recent sessions to keep
    private let maxRecentSessions: Int

    public init(maxRecentSessions: Int = 10) {
        self.maxRecentSessions = maxRecentSessions
    }

    // MARK: - Event Processing

    /// Processes a session event and updates state accordingly.
    public func processEvent(_ event: SessionEvent) {
        switch event.eventName {
        case .sessionStart:
            handleSessionStart(event)
        case .sessionEnd:
            handleSessionEnd(event)
        case .taskCompleted:
            handleTaskCompleted(event)
        case .subagentStart:
            handleSubagentStart(event)
        case .subagentStop:
            handleSubagentStop(event)
        case .stop:
            handleStop(event)
        }
    }

    // MARK: - Queries

    /// Whether there's at least one active Claude Code session
    public var hasActiveSession: Bool {
        !activeSessions.isEmpty
    }

    /// Convenience: the most recently started active session (for backward compat)
    public var activeSession: ClaudeSession? {
        activeSessions.last
    }

    // MARK: - Private Handlers

    private func handleSessionStart(_ event: SessionEvent) {
        // Skip if we already track this session
        guard !activeSessions.contains(where: { $0.id == event.sessionId }) else { return }

        activeSessions.append(ClaudeSession(
            id: event.sessionId,
            cwd: event.cwd,
            startedAt: event.receivedAt,
            name: event.name
        ))
    }

    private func handleSessionEnd(_ event: SessionEvent) {
        guard let index = activeSessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        var session = activeSessions.remove(at: index)
        session.end(at: event.receivedAt)
        addToRecent(session)
    }

    private func handleTaskCompleted(_ event: SessionEvent) {
        guard let index = activeSessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        activeSessions[index].taskCompleted()
    }

    private func handleSubagentStart(_ event: SessionEvent) {
        guard let index = activeSessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        activeSessions[index].subagentStarted()
    }

    private func handleSubagentStop(_ event: SessionEvent) {
        guard let index = activeSessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        activeSessions[index].subagentStopped()
    }

    private func handleStop(_ event: SessionEvent) {
        guard let index = activeSessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        activeSessions[index].stop()
    }

    private func addToRecent(_ session: ClaudeSession) {
        recentSessions.insert(session, at: 0)
        if recentSessions.count > maxRecentSessions {
            recentSessions = Array(recentSessions.prefix(maxRecentSessions))
        }
    }
}
