import Foundation
import Network
import Domain

/// Lightweight HTTP server using Network.framework (NWListener).
/// Listens on localhost only. Handles:
/// - POST /hook — receives session events from Claude Code hooks
/// - GET /api/* — serves quota data for MCP and other consumers
/// All mutable state is accessed only from `queue` — NWListener callbacks
/// and external callers both dispatch onto it, so no queue.sync is needed
/// inside callbacks (which already run on queue).
public final class HookHTTPServer: @unchecked Sendable {
    private var listener: NWListener?
    private var continuation: AsyncStream<SessionEvent>.Continuation?
    private let defaultPort: UInt16

    /// Optional query handler for serving API requests (MCP, etc.)
    public var queryHandler: (any QuotaQueryHandler)?

    /// Serial queue for synchronizing all mutable state.
    /// NWListener and NWConnection callbacks also run on this queue.
    private let queue = DispatchQueue(label: "com.nguyentheanh.burnrate.hookserver")

    /// The actual port the server is listening on
    public private(set) var actualPort: UInt16 = 0

    public init(defaultPort: UInt16 = HookConstants.defaultPort) {
        self.defaultPort = defaultPort
    }

    /// Starts the HTTP server and returns a stream of parsed session events.
    public func start() async throws -> AsyncStream<SessionEvent> {
        let stream = AsyncStream<SessionEvent> { continuation in
            self.queue.async {
                self.continuation = continuation
            }
            continuation.onTermination = { _ in
                self.stop()
            }
        }

        // Try default port first, fall back to auto-assign
        let port: NWEndpoint.Port
        if let preferredPort = NWEndpoint.Port(rawValue: defaultPort) {
            port = preferredPort
        } else {
            port = .any
        }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: port)

        let listener = try NWListener(using: parameters)

        // stateUpdateHandler runs on `queue` (set by listener.start below),
        // so we access mutable state directly — no queue.sync needed.
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let actualPort = listener.port?.rawValue {
                    self.actualPort = actualPort
                    try? PortDiscovery.writePort(Int(actualPort))
                    AppLog.hooks.info("Hook HTTP server listening on port \(actualPort)")
                }
            case .failed(let error):
                AppLog.hooks.error("Hook HTTP server failed: \(error.localizedDescription)")
                self.continuation?.finish()
            default:
                break
            }
        }

        // newConnectionHandler also runs on `queue`.
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: queue)
        queue.async { self.listener = listener }

        return stream
    }

    /// Stops the HTTP server and cleans up.
    public func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            continuation?.finish()
            continuation = nil
            PortDiscovery.removePortFile()
            AppLog.hooks.info("Hook HTTP server stopped")
        }
    }

    // MARK: - Connection Handling

    /// Runs on `queue` (via newConnectionHandler).
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveFullRequest(connection: connection, buffer: Data())
    }

    /// Accumulates data until the full HTTP request (headers + body per Content-Length) is received.
    private func receiveFullRequest(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data, error == nil else {
                if let error {
                    AppLog.hooks.debug("Connection error: \(error.localizedDescription)")
                }
                self?.sendResponse(connection: connection, statusCode: 400, body: nil)
                return
            }

            var accumulated = buffer
            accumulated.append(data)

            // Hard size limit (64KB)
            guard accumulated.count <= 65536 else {
                self.sendResponse(connection: connection, statusCode: 400, body: nil)
                return
            }

            // Check if we have complete headers (\r\n\r\n)
            let separator = Data([0x0D, 0x0A, 0x0D, 0x0A])
            guard let separatorRange = accumulated.range(of: separator) else {
                if isComplete {
                    self.sendResponse(connection: connection, statusCode: 400, body: nil)
                } else {
                    self.receiveFullRequest(connection: connection, buffer: accumulated)
                }
                return
            }

            // Parse Content-Length to know how much body to expect
            let headerData = accumulated[accumulated.startIndex..<separatorRange.lowerBound]
            let expectedBody = self.parseContentLength(headerData)
            let bodyStart = separatorRange.upperBound
            let bodyReceived = accumulated.distance(from: bodyStart, to: accumulated.endIndex)

            if bodyReceived >= expectedBody || isComplete {
                self.routeHTTPRequest(accumulated, connection: connection)
            } else {
                self.receiveFullRequest(connection: connection, buffer: accumulated)
            }
        }
    }

    /// Extracts Content-Length from raw header bytes, defaulting to 0.
    private func parseContentLength(_ headerData: Data) -> Int {
        guard let headers = String(data: headerData, encoding: .utf8)?.lowercased() else { return 0 }
        guard let range = headers.range(of: "content-length:") else { return 0 }
        let afterColon = headers[range.upperBound...]
        let valueEnd = afterColon.firstIndex(of: "\r") ?? afterColon.endIndex
        let value = afterColon[..<valueEnd].trimmingCharacters(in: .whitespaces)
        return max(Int(value) ?? 0, 0)
    }

    /// Parses the HTTP request line and dispatches to the appropriate handler.
    private func routeHTTPRequest(_ rawData: Data, connection: NWConnection) {
        guard let rawString = String(data: rawData, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: nil)
            return
        }

        let separatorRange = rawString.range(of: "\r\n\r\n")
        let headerPart: Substring
        if let range = separatorRange {
            headerPart = rawString[rawString.startIndex..<range.lowerBound]
        } else {
            headerPart = rawString[rawString.startIndex...]
        }

        // Parse request line: "METHOD /path HTTP/1.1"
        let requestLine = headerPart.prefix(while: { $0 != "\r" && $0 != "\n" })
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: nil)
            return
        }

        let method = String(parts[0])
        let fullPath = String(parts[1])

        // Split path from query string
        let pathAndQuery = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(pathAndQuery[0])
        let queryString = pathAndQuery.count > 1 ? String(pathAndQuery[1]) : nil

        switch (method, path) {
        case ("POST", "/hook"):
            handleHookRequest(rawString: rawString, separatorRange: separatorRange, connection: connection)

        case ("GET", "/api/status"):
            handleAPIRequest(connection: connection) { handler in
                await handler.allProviderStatus()
            }

        case ("GET", _) where path.hasPrefix("/api/provider/"):
            let providerId = String(path.dropFirst("/api/provider/".count))
            handleProviderDetailRequest(connection: connection, providerId: providerId)

        case ("GET", "/api/recommendation"):
            let complexity = parseQueryParam(queryString, key: "complexity")
                .flatMap { TaskComplexity(rawValue: $0) } ?? .medium
            handleAPIRequest(connection: connection) { handler in
                await handler.modelRecommendation(complexity: complexity)
            }

        case ("POST", "/api/refresh"):
            handleAPIRequest(connection: connection) { handler in
                await handler.refreshAll()
            }

        default:
            AppLog.hooks.debug("Rejected \(method) \(path)")
            sendResponse(connection: connection, statusCode: 404, body: nil)
        }
    }

    // MARK: - Hook Handler (existing behavior)

    private func handleHookRequest(rawString: String, separatorRange: Range<String.Index>?, connection: NWConnection) {
        defer { sendResponse(connection: connection, statusCode: 200, body: nil) }

        guard let separatorRange else {
            AppLog.hooks.debug("No HTTP body found in hook request")
            return
        }

        let bodyString = rawString[separatorRange.upperBound...]
        guard let bodyData = bodyString.data(using: .utf8) else { return }

        if let event = SessionEventParser.parse(bodyData) {
            AppLog.hooks.info("Received hook event: \(event.eventName.rawValue) for session \(event.sessionId)")
            continuation?.yield(event)
        } else {
            AppLog.hooks.warning("Failed to parse hook event payload")
        }
    }

    // MARK: - API Handlers

    /// Handles provider detail requests with distinct error messages.
    private func handleProviderDetailRequest(connection: NWConnection, providerId: String) {
        guard let queryHandler else {
            let error = ["error": "MCP query handler not configured"]
            let body = try? JSONEncoder().encode(error)
            sendResponse(connection: connection, statusCode: 503, contentType: "application/json", body: body)
            return
        }

        Task {
            let result = await queryHandler.providerDetail(id: providerId)
            switch result {
            case .success(let detail):
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let body = try? encoder.encode(detail)
                self.sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: body)
            case .unknownProvider:
                let error = ["error": "Unknown provider: \(providerId)"]
                let body = try? JSONEncoder().encode(error)
                self.sendResponse(connection: connection, statusCode: 404, contentType: "application/json", body: body)
            case .noDataYet:
                let error = ["error": "Provider '\(providerId)' has no data yet. Wait for a refresh cycle or call refresh_quotas."]
                let body = try? JSONEncoder().encode(error)
                self.sendResponse(connection: connection, statusCode: 202, contentType: "application/json", body: body)
            }
        }
    }

    /// Handles an API request by calling the query handler and sending the JSON response.
    private func handleAPIRequest<T: Encodable>(
        connection: NWConnection,
        handler: @escaping @Sendable (any QuotaQueryHandler) async -> T?
    ) {
        guard let queryHandler else {
            let error = ["error": "MCP query handler not configured"]
            let body = try? JSONEncoder().encode(error)
            sendResponse(connection: connection, statusCode: 503, contentType: "application/json", body: body)
            return
        }

        Task {
            let result = await handler(queryHandler)
            if let result {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let body = try? encoder.encode(result)
                self.sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: body)
            } else {
                let error = ["error": "Not found"]
                let body = try? JSONEncoder().encode(error)
                self.sendResponse(connection: connection, statusCode: 404, contentType: "application/json", body: body)
            }
        }
    }

    // MARK: - Response Writing

    private func sendResponse(
        connection: NWConnection,
        statusCode: Int,
        contentType: String? = nil,
        body: Data? = nil
    ) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 503: statusText = "Service Unavailable"
        default: statusText = "Error"
        }

        var header = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        header += "Connection: close\r\n"
        if let contentType {
            header += "Content-Type: \(contentType)\r\n"
        }
        header += "Content-Length: \(body?.count ?? 0)\r\n"
        header += "\r\n"

        var responseData = header.data(using: .utf8) ?? Data()
        if let body {
            responseData.append(body)
        }

        connection.send(
            content: responseData,
            contentContext: .finalMessage,
            isComplete: true,
            completion: .contentProcessed { _ in
                connection.cancel()
            }
        )
    }

    // MARK: - Query String Parsing

    private func parseQueryParam(_ queryString: String?, key: String) -> String? {
        guard let queryString else { return nil }
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, String(kv[0]) == key {
                return String(kv[1]).removingPercentEncoding
            }
        }
        return nil
    }
}
