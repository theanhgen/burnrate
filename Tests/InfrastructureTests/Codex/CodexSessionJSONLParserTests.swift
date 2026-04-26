import Foundation
import Testing
@testable import Infrastructure

@Suite
struct CodexSessionJSONLParserTests {
    let parser = CodexSessionJSONLParser()

    @Test func `parses token_count event with last_token_usage`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:15.745Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":30065,"cached_input_tokens":9600,"output_tokens":433,"reasoning_output_tokens":299,"total_tokens":30498},"last_token_usage":{"input_tokens":30065,"cached_input_tokens":9600,"output_tokens":433,"reasoning_output_tokens":299,"total_tokens":30498}},"rate_limits":{"limit_id":"codex","primary":{"used_percent":17.0}}}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 1)
        #expect(records[0].inputTokens == 30065)
        #expect(records[0].outputTokens == 433)
        #expect(records[0].cachedInputTokens == 9600)
        #expect(records[0].reasoningOutputTokens == 299)
        #expect(records[0].totalTokens == 30498)
    }

    @Test func `skips non-token_count events`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:05.422Z","type":"session_meta","payload":{"id":"test","model_provider":"openai"}}
        {"timestamp":"2026-04-03T15:54:05.423Z","type":"event_msg","payload":{"type":"task_started","turn_id":"test"}}
        {"timestamp":"2026-04-03T15:54:15.745Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":50,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":150}},"rate_limits":{}}}
        {"timestamp":"2026-04-03T15:55:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[]}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 1)
        #expect(records[0].inputTokens == 100)
    }

    @Test func `skips token_count events with null info`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:05.644Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"codex"}}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 0)
    }

    @Test func `skips events with zero tokens`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:15.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":0,"output_tokens":0,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":0}},"rate_limits":{}}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 0)
    }

    @Test func `parses multiple token_count events`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:15.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"output_tokens":200,"cached_input_tokens":500,"reasoning_output_tokens":100,"total_tokens":1200}},"rate_limits":{}}}
        {"timestamp":"2026-04-03T15:55:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":2000,"output_tokens":400,"cached_input_tokens":800,"reasoning_output_tokens":200,"total_tokens":2400}},"rate_limits":{}}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 2)
        #expect(records[0].totalTokens == 1200)
        #expect(records[1].totalTokens == 2400)
    }

    @Test func `handles malformed JSON lines gracefully`() {
        let jsonl = """
        not json at all
        {"timestamp":"2026-04-03T15:54:15.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":50,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":150}},"rate_limits":{}}}
        {"incomplete": true
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 1)
    }

    @Test func `handles missing optional token fields`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:15.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":50}},"rate_limits":{}}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 1)
        #expect(records[0].cachedInputTokens == 0)
        #expect(records[0].reasoningOutputTokens == 0)
    }

    @Test func `parses ISO8601 timestamp correctly`() {
        let jsonl = """
        {"timestamp":"2026-04-03T15:54:15.745Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":50,"cached_input_tokens":0,"reasoning_output_tokens":0,"total_tokens":150}},"rate_limits":{}}}
        """
        let records = parser.parse(content: jsonl)
        #expect(records.count == 1)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: records[0].timestamp)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 3)
        #expect(components.hour == 15)
        #expect(components.minute == 54)
    }
}
