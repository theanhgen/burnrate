import Foundation

// MARK: - JSON-RPC 2.0

struct JSONRPCRequest: Decodable {
    let jsonrpc: String
    let id: AnyCodableValue?
    /// Whether the `id` field was present in the JSON (even if null).
    /// Absent id = notification; present id (including null) = request.
    let idPresent: Bool
    let method: String
    let params: AnyCodableValue?

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        method = try container.decode(String.self, forKey: .method)
        params = try container.decodeIfPresent(AnyCodableValue.self, forKey: .params)
        if container.contains(.id) {
            id = try container.decode(AnyCodableValue.self, forKey: .id)
            idPresent = true
        } else {
            id = nil
            idPresent = false
        }
    }
}

struct JSONRPCResponse: Encodable {
    let jsonrpc: String
    let id: AnyCodableValue?
    let result: AnyCodableValue?
    let error: JSONRPCError?

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }

    /// Custom encoding: JSON-RPC 2.0 requires `id` in every response, even as null.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        if let id {
            try container.encode(id, forKey: .id)
        } else {
            try container.encodeNil(forKey: .id)
        }
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(error, forKey: .error)
    }

    static func success(id: AnyCodableValue?, result: some Encodable) -> JSONRPCResponse {
        let encoded = try? JSONEncoder().encode(result)
        let value = encoded.flatMap { try? JSONDecoder().decode(AnyCodableValue.self, from: $0) }
        return JSONRPCResponse(jsonrpc: "2.0", id: id, result: value, error: nil)
    }

    static func error(id: AnyCodableValue?, code: Int, message: String) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", id: id, result: nil, error: JSONRPCError(code: code, message: message))
    }
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
}

// MARK: - MCP Protocol Types

struct MCPInitializeResult: Codable {
    let protocolVersion: String
    let capabilities: MCPCapabilities
    let serverInfo: MCPServerInfo
}

struct MCPCapabilities: Codable {
    let tools: MCPToolsCapability?
}

struct MCPToolsCapability: Codable {
    let listChanged: Bool?
}

struct MCPServerInfo: Codable {
    let name: String
    let version: String
}

struct MCPToolsListResult: Codable {
    let tools: [MCPToolDefinition]
}

struct MCPToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: InputSchema
}

struct InputSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]?
    let required: [String]?
}

struct PropertySchema: Codable {
    let type: String
    let description: String?
    let `enum`: [String]?
}

struct MCPToolCallParams: Codable {
    let name: String
    let arguments: [String: AnyCodableValue]?
}

struct MCPToolResult: Codable {
    let content: [MCPContent]
    let isError: Bool?
}

struct MCPContent: Codable {
    let type: String
    let text: String
}

// MARK: - AnyCodableValue (generic JSON value wrapper)

enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let val = try? container.decode(Bool.self) {
            self = .bool(val)
        } else if let val = try? container.decode(Int.self) {
            self = .int(val)
        } else if let val = try? container.decode(Double.self) {
            self = .double(val)
        } else if let val = try? container.decode(String.self) {
            self = .string(val)
        } else if let val = try? container.decode([AnyCodableValue].self) {
            self = .array(val)
        } else if let val = try? container.decode([String: AnyCodableValue].self) {
            self = .object(val)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let val): try container.encode(val)
        case .int(let val): try container.encode(val)
        case .double(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .null: try container.encodeNil()
        case .array(let val): try container.encode(val)
        case .object(let val): try container.encode(val)
        }
    }

    var stringValue: String? {
        if case .string(let val) = self { return val }
        return nil
    }
}
