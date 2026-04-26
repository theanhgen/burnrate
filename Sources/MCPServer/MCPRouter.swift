import Foundation

/// Routes MCP tool calls to HTTP requests against the burnrate app.
enum MCPRouter {

    // MARK: - Tool Definitions

    static let tools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "get_quota_status",
            description: "Get current quota status across all AI providers monitored by burnrate. Shows remaining quota percentages, burn rates, and overall health for each enabled provider.",
            inputSchema: InputSchema(type: "object", properties: nil, required: nil)
        ),
        MCPToolDefinition(
            name: "get_provider_detail",
            description: "Get detailed quota information for a specific AI provider including model-specific limits, cost usage, pace analysis, and reset times.",
            inputSchema: InputSchema(
                type: "object",
                properties: [
                    "provider_id": PropertySchema(
                        type: "string",
                        description: "Provider ID",
                        enum: ["claude", "codex", "gemini", "copilot", "antigravity", "zai", "kimi", "amp", "kiro", "cursor", "bedrock", "minimax", "alibaba", "mistral"]
                    ),
                ],
                required: ["provider_id"]
            )
        ),
        MCPToolDefinition(
            name: "get_model_recommendation",
            description: "Get a recommendation for which AI provider to use based on task complexity and current quota availability. Considers burn rate, remaining quota, and model-specific limits to suggest the best option.",
            inputSchema: InputSchema(
                type: "object",
                properties: [
                    "task_complexity": PropertySchema(
                        type: "string",
                        description: "low = simple edits, lookups, boilerplate (use cheapest). medium = feature implementation, test writing (balanced). high = architecture, complex refactors, multi-file reasoning (use best available).",
                        enum: ["low", "medium", "high"]
                    ),
                ],
                required: ["task_complexity"]
            )
        ),
        MCPToolDefinition(
            name: "refresh_quotas",
            description: "Trigger a fresh quota probe across all enabled providers. Use when data might be stale or after intensive usage. Returns updated status.",
            inputSchema: InputSchema(type: "object", properties: nil, required: nil)
        ),
    ]

    // MARK: - Input Validation

    private static let validProviderIds: Set<String> = [
        "claude", "codex", "gemini", "copilot", "antigravity", "zai",
        "kimi", "amp", "kiro", "cursor", "bedrock", "minimax", "alibaba", "mistral"
    ]

    private static let validComplexities: Set<String> = ["low", "medium", "high"]

    /// Validates tool arguments against the advertised schema. Throws on violations.
    static func validateArguments(name: String, arguments: [String: AnyCodableValue]?) throws {
        switch name {
        case "get_provider_detail":
            guard let providerId = arguments?["provider_id"]?.stringValue else {
                throw ValidationError.missingRequired("provider_id")
            }
            guard validProviderIds.contains(providerId) else {
                throw ValidationError.invalidEnum("provider_id", providerId, validProviderIds.sorted())
            }
        case "get_model_recommendation":
            guard let complexity = arguments?["task_complexity"]?.stringValue else {
                throw ValidationError.missingRequired("task_complexity")
            }
            guard validComplexities.contains(complexity) else {
                throw ValidationError.invalidEnum("task_complexity", complexity, validComplexities.sorted())
            }
        default:
            break
        }
    }

    // MARK: - Route Tool Calls

    static func handleToolCall(name: String, arguments: [String: AnyCodableValue]?, port: Int) async throws -> String {
        let data: Data
        switch name {
        case "get_quota_status":
            data = try await HTTPBridge.get(port: port, path: "/api/status")

        case "get_provider_detail":
            guard let providerId = arguments?["provider_id"]?.stringValue else {
                throw RouterError.missingArgument("provider_id")
            }
            data = try await HTTPBridge.get(port: port, path: "/api/provider/\(providerId)")

        case "get_model_recommendation":
            let complexity = arguments?["task_complexity"]?.stringValue ?? "medium"
            data = try await HTTPBridge.get(port: port, path: "/api/recommendation?complexity=\(complexity)")

        case "refresh_quotas":
            data = try await HTTPBridge.post(port: port, path: "/api/refresh")

        default:
            throw RouterError.unknownTool(name)
        }

        // Pretty-print the JSON for readability in agent context
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return str
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    enum RouterError: Error, LocalizedError {
        case unknownTool(String)
        case missingArgument(String)

        var errorDescription: String? {
            switch self {
            case .unknownTool(let name): "Unknown tool: \(name)"
            case .missingArgument(let arg): "Missing required argument: \(arg)"
            }
        }
    }

    enum ValidationError: Error, LocalizedError {
        case missingRequired(String)
        case invalidEnum(String, String, [String])

        var errorDescription: String? {
            switch self {
            case .missingRequired(let field):
                "Missing required argument: \(field)"
            case .invalidEnum(let field, let value, let valid):
                "Invalid value '\(value)' for \(field). Must be one of: \(valid.joined(separator: ", "))"
            }
        }
    }
}
