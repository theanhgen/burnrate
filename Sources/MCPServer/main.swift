import Foundation

/// burnrate-mcp: MCP stdio server that bridges AI coding agents to the burnrate app.
/// Reads JSON-RPC from stdin, translates tool calls to HTTP requests to the running
/// burnrate app, and writes JSON-RPC responses to stdout.

// Discover the burnrate app's HTTP port (lazy -- checked at tool-call time if missing)
let discoveredPort = HTTPBridge.discoverPort()

// Process stdin line by line (JSON-RPC over stdio)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

// Use a semaphore to block the main thread while async work completes
let semaphore = DispatchSemaphore(value: 0)

Task {
    defer { semaphore.signal() }

    var isInitialized = false

    while let line = readLine(strippingNewline: true) {
        guard !line.isEmpty else { continue }

        guard let data = line.data(using: .utf8) else {
            writeResponse(JSONRPCResponse.error(id: nil, code: -32700, message: "Parse error"))
            continue
        }

        // Detect batch requests (JSON array) — not supported
        if let first = data.first, first == UInt8(ascii: "[") {
            writeResponse(JSONRPCResponse.error(id: nil, code: -32600, message: "Batch requests are not supported"))
            continue
        }

        guard let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
            // Valid JSON but invalid request shape → -32600; unparseable JSON → -32700
            // Since we can't distinguish reliably after decode failure, use -32700
            writeResponse(JSONRPCResponse.error(id: nil, code: -32700, message: "Parse error"))
            continue
        }

        // Validate JSON-RPC version
        guard request.jsonrpc == "2.0" else {
            writeResponse(JSONRPCResponse.error(id: request.id, code: -32600, message: "Invalid Request: jsonrpc must be \"2.0\""))
            continue
        }

        // Validate id type if present (JSON-RPC 2.0: must be string, integer, or null)
        if request.idPresent, let id = request.id {
            switch id {
            case .string, .int, .null: break
            default:
                writeResponse(JSONRPCResponse.error(id: nil, code: -32600, message: "Invalid Request: id must be string, integer, or null"))
                continue
            }
        }

        // Notifications have no id field — must not receive a response
        let isNotification = !request.idPresent

        // Enforce MCP lifecycle: reject requests before initialize
        if !isInitialized && request.method != "initialize" && !isNotification {
            writeResponse(JSONRPCResponse.error(
                id: request.id,
                code: -32600,
                message: "Server not initialized. Send 'initialize' first."
            ))
            continue
        }

        if let response = await handleRequest(request), !isNotification {
            writeResponse(response)
        }

        // Track initialization state
        if request.method == "initialize" {
            isInitialized = true
        }
    }
}

semaphore.wait()

// MARK: - Request Handling

func handleRequest(_ request: JSONRPCRequest, port: Int? = discoveredPort) async -> JSONRPCResponse? {
    switch request.method {
    case "initialize":
        let result = MCPInitializeResult(
            protocolVersion: "2024-11-05",
            capabilities: MCPCapabilities(
                tools: MCPToolsCapability(listChanged: false)
            ),
            serverInfo: MCPServerInfo(name: "burnrate", version: "0.1.0")
        )
        return .success(id: request.id, result: result)

    case "notifications/initialized", "notifications/cancelled":
        // Client notifications -- no response
        return nil

    case "tools/list":
        let result = MCPToolsListResult(tools: MCPRouter.tools)
        return .success(id: request.id, result: result)

    case "tools/call":
        guard let port else {
            let result = MCPToolResult(
                content: [MCPContent(type: "text", text: "burnrate app is not running. Launch burnrate to use quota monitoring.")],
                isError: true
            )
            return .success(id: request.id, result: result)
        }

        guard let paramsData = encodeValue(request.params),
              let params = try? JSONDecoder().decode(MCPToolCallParams.self, from: paramsData) else {
            return .error(id: request.id, code: -32602, message: "Invalid tool call parameters")
        }

        // Validate tool name exists
        guard MCPRouter.tools.contains(where: { $0.name == params.name }) else {
            return .error(id: request.id, code: -32602, message: "Unknown tool: \(params.name). Available: \(MCPRouter.tools.map(\.name).joined(separator: ", "))")
        }

        // Validate arguments against advertised schema
        do {
            try MCPRouter.validateArguments(name: params.name, arguments: params.arguments)
        } catch {
            return .error(id: request.id, code: -32602, message: error.localizedDescription)
        }

        do {
            let text = try await MCPRouter.handleToolCall(
                name: params.name,
                arguments: params.arguments,
                port: port
            )
            let result = MCPToolResult(
                content: [MCPContent(type: "text", text: text)],
                isError: nil
            )
            return .success(id: request.id, result: result)
        } catch {
            // Downstream execution errors (HTTP failures, app errors) are tool-level errors
            let result = MCPToolResult(
                content: [MCPContent(type: "text", text: error.localizedDescription)],
                isError: true
            )
            return .success(id: request.id, result: result)
        }

    default:
        return .error(id: request.id, code: -32601, message: "Method not found: \(request.method)")
    }
}

// MARK: - Helpers

func writeResponse(_ response: JSONRPCResponse) {
    guard let data = try? encoder.encode(response),
          let json = String(data: data, encoding: .utf8) else { return }
    print(json)
    fflush(stdout)
}

func encodeValue(_ value: AnyCodableValue?) -> Data? {
    guard let value else { return nil }
    return try? JSONEncoder().encode(value)
}
