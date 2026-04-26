import Foundation

/// Describes the complexity of a coding task for model recommendation.
public enum TaskComplexity: String, Sendable, Codable, CaseIterable {
    /// Simple edits, lookups, typo fixes, boilerplate — use cheapest available
    case low
    /// Feature implementation, test writing, moderate coding — balanced choice
    case medium
    /// Architecture, complex refactors, multi-file reasoning — use best available
    case high
}
