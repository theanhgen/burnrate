import Foundation

/// A single token usage record extracted from a Codex session JSONL file.
/// Uses `last_token_usage` (per-turn delta) from `token_count` events.
struct CodexTokenUsageRecord: Sendable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cachedInputTokens: Int
    let reasoningOutputTokens: Int
    let timestamp: Date

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

/// Parses Codex session JSONL files to extract token usage records.
/// Each file lives at ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl
/// and contains `event_msg` entries with `type: "token_count"`.
struct CodexSessionJSONLParser {
    /// Parse a single JSONL file and extract per-turn token usage records.
    func parse(fileURL: URL) throws -> [CodexTokenUsageRecord] {
        let data = try Data(contentsOf: fileURL)
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        return parse(content: content)
    }

    /// Parse content string directly (for testing).
    func parse(content: String) -> [CodexTokenUsageRecord] {
        var records: [CodexTokenUsageRecord] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  json["type"] as? String == "event_msg",
                  let payload = json["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let lastUsage = info["last_token_usage"] as? [String: Any],
                  let timestampStr = json["timestamp"] as? String,
                  let timestamp = dateFormatter.date(from: timestampStr) ?? fallbackFormatter.date(from: timestampStr)
            else { continue }

            let inputTokens = lastUsage["input_tokens"] as? Int ?? 0
            let outputTokens = lastUsage["output_tokens"] as? Int ?? 0
            let cachedInput = lastUsage["cached_input_tokens"] as? Int ?? 0
            let reasoningOutput = lastUsage["reasoning_output_tokens"] as? Int ?? 0

            // Skip events with no actual tokens (e.g., initial event with null info)
            guard inputTokens > 0 || outputTokens > 0 else { continue }

            records.append(CodexTokenUsageRecord(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cachedInputTokens: cachedInput,
                reasoningOutputTokens: reasoningOutput,
                timestamp: timestamp
            ))
        }

        return records
    }
}
