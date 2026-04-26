import Foundation

/// Makes HTTP requests to the running burnrate app's HookHTTPServer.
enum HTTPBridge {
    /// URLSession with a 10-second timeout for all requests.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    /// Reads the port from the discovery file.
    static func discoverPort() -> Int? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let portFile = "\(home)/.claude/burnrate-hook-port"
        guard let contents = try? String(contentsOfFile: portFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let port = Int(contents) else {
            return nil
        }
        return port
    }

    /// Performs a GET request to the burnrate app and returns the response body.
    static func get(port: Int, path: String) async throws -> Data {
        let url = URL(string: "http://localhost:\(port)\(path)")!
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw BridgeError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// Performs a POST request to the burnrate app and returns the response body.
    static func post(port: Int, path: String) async throws -> Data {
        let url = URL(string: "http://localhost:\(port)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw BridgeError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    enum BridgeError: Error, LocalizedError {
        case appNotRunning
        case invalidResponse
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .appNotRunning:
                "burnrate app is not running. Launch burnrate to use quota monitoring."
            case .invalidResponse:
                "Invalid response from burnrate app."
            case .httpError(let code, let body):
                "HTTP \(code): \(body)"
            }
        }
    }
}
