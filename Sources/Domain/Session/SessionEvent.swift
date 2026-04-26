import Foundation

/// Represents a hook event received from Claude Code.
/// These events map directly to Claude Code's hook system events.
public struct SessionEvent: Sendable, Equatable, Codable {
    /// The session ID from Claude Code
    public let sessionId: String

    /// The type of hook event
    public let eventName: EventName

    /// The working directory where Claude Code is running
    public let cwd: String

    /// When this event was received
    public let receivedAt: Date

    /// Optional session name (e.g., the initial prompt or task description)
    public let name: String?

    public init(
        sessionId: String,
        eventName: EventName,
        cwd: String,
        receivedAt: Date = Date(),
        name: String? = nil
    ) {
        self.sessionId = sessionId
        self.eventName = eventName
        self.cwd = cwd
        self.receivedAt = receivedAt
        self.name = name
    }

    /// The types of hook events from Claude Code
    public enum EventName: String, Sendable, Equatable, Codable {
        case sessionStart = "SessionStart"
        case sessionEnd = "SessionEnd"
        case taskCompleted = "TaskCompleted"
        case subagentStart = "SubagentStart"
        case subagentStop = "SubagentStop"
        case stop = "Stop"
    }
}
