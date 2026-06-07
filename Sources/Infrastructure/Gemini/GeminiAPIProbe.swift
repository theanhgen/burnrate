import Foundation
import Domain

internal struct GeminiAPIProbe {
    private let homeDirectory: String
    private let timeout: TimeInterval
    private let networkClient: any NetworkClient
    #if !MAS_BUILD
    private let cliExecutor: CLIExecutor
    private let clock: any Clock
    #endif
    #if MAS_BUILD
    private let bookmarkManager: (any BookmarkManaging)?
    #endif

    private static let quotaEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    private static let credentialsPath = "/.gemini/oauth_creds.json"

    private let maxRetries: Int

    #if MAS_BUILD
    init(
        homeDirectory: String,
        timeout: TimeInterval,
        networkClient: any NetworkClient,
        maxRetries: Int = 3,
        bookmarkManager: (any BookmarkManaging)? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.timeout = timeout
        self.networkClient = networkClient
        self.maxRetries = maxRetries
        self.bookmarkManager = bookmarkManager
    }
    #else
    init(
        homeDirectory: String,
        timeout: TimeInterval,
        networkClient: any NetworkClient,
        maxRetries: Int = 3,
        cliExecutor: CLIExecutor = DefaultCLIExecutor(),
        clock: any Clock = SystemClock()
    ) {
        self.homeDirectory = homeDirectory
        self.timeout = timeout
        self.networkClient = networkClient
        self.maxRetries = maxRetries
        self.cliExecutor = cliExecutor
        self.clock = clock
    }
    #endif

    func probe() async throws -> UsageSnapshot {
        do {
            return try await probeAPI()
        } catch ProbeError.authenticationRequired {
            #if MAS_BUILD
            // MAS build cannot run CLI tools; propagate auth error directly
            AppLog.probes.warning("Gemini: Token expired, CLI refresh unavailable in MAS build")
            throw ProbeError.authenticationRequired
            #else
            AppLog.probes.info("Gemini: Token expired, attempting CLI refresh...")
            do {
                try await refreshTokenViaCLI()
            } catch ProbeError.cliNotFound {
                AppLog.probes.warning("Gemini: CLI not available for token refresh, authentication required")
                throw ProbeError.authenticationRequired
            } catch {
                // CLI may have timed out or exited with an error but still written a fresh
                // token to disk (refresh happens at startup, before any prompt is processed).
                AppLog.probes.warning("Gemini: CLI exited with error (\(error.localizedDescription)), retrying API anyway")
            }
            AppLog.probes.info("Gemini: Retrying API probe after token refresh...")
            do {
                return try await probeAPI()
            } catch ProbeError.authenticationRequired {
                AppLog.probes.error("Gemini: API probe failed with authentication error even after token refresh")
                throw ProbeError.authenticationRequired
            } catch {
                AppLog.probes.error("Gemini: API probe failed after token refresh: \(error)")
                throw error
            }
            #endif
        }
    }

    private func probeAPI() async throws -> UsageSnapshot {
        let creds = try loadCredentials()
        AppLog.probes.debug("Gemini credentials loaded, expiry: \(String(describing: creds.expiryDate))")

        guard let accessToken = creds.accessToken, !accessToken.isEmpty else {
            AppLog.probes.error("Gemini probe failed: no access token in credentials file")
            throw ProbeError.authenticationRequired
        }

        // Discover the Gemini project ID for accurate quota data
        // Uses retry logic to handle cold-start network delays
        let repository = GeminiProjectRepository(networkClient: networkClient, timeout: timeout, maxRetries: maxRetries)
        let projectId = await repository.fetchBestProject(accessToken: accessToken)?.projectId

        if projectId == nil {
            AppLog.probes.warning("Gemini: Project discovery failed, proceeding without project ID (quota may be less accurate)")
        } else {
            AppLog.probes.debug("Gemini: Using project ID \(projectId ?? "")")
        }

        guard let url = URL(string: Self.quotaEndpoint) else {
            throw ProbeError.executionFailed("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include project ID if discovered for accurate quota
        if let projectId {
            request.httpBody = Data("{\"project\": \"\(projectId)\"}".utf8)
        } else {
            request.httpBody = Data("{}".utf8)
        }
        request.timeoutInterval = timeout

        let (data, response) = try await networkClient.request(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProbeError.executionFailed("Invalid response")
        }

        AppLog.probes.debug("Gemini API response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            AppLog.probes.error("Gemini probe failed: authentication required (401)")
            throw ProbeError.authenticationRequired
        }

        guard httpResponse.statusCode == 200 else {
            AppLog.probes.error("Gemini probe failed: HTTP error \(httpResponse.statusCode)")
            throw ProbeError.executionFailed("HTTP \(httpResponse.statusCode)")
        }

        // Log raw response at debug level
        if let responseText = String(data: data, encoding: .utf8) {
            AppLog.probes.debug("Gemini API response: \(responseText)")
        }

        let snapshot = try mapToSnapshot(data)
        AppLog.probes.info("Gemini probe success: \(snapshot.quotas.count) quotas found")
        for quota in snapshot.quotas {
            AppLog.probes.info("  - \(quota.quotaType.displayName): \(Int(quota.percentRemaining))% remaining")
        }

        return snapshot
    }

    #if !MAS_BUILD
    /// Runs the Gemini CLI in non-interactive mode to trigger OAuth token refresh.
    /// The CLI refreshes the token on startup and writes it back to oauth_creds.json.
    private func refreshTokenViaCLI() async throws {
        guard cliExecutor.locate("gemini") != nil else {
            AppLog.probes.error("Gemini CLI not found, cannot refresh token")
            throw ProbeError.cliNotFound("gemini")
        }

        AppLog.probes.debug("Gemini: Running CLI (non-interactive) to refresh OAuth token...")

        // Use -p (headless/non-interactive) so the CLI exits immediately after startup.
        // The token refresh happens during initialization before any prompt is processed.
        _ = try? cliExecutor.execute(
            binary: "gemini",
            args: ["-p", ""],
            input: "",
            timeout: 15.0,
            workingDirectory: nil,
            autoResponses: [:]
        )

        try await clock.sleep(nanoseconds: 1_500_000_000)

        AppLog.probes.debug("Gemini: CLI token refresh attempt completed")
    }
    #endif

    private func mapToSnapshot(_ data: Data) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QuotaResponse.self, from: data)

        guard let buckets = response.buckets, !buckets.isEmpty else {
            AppLog.probes.error("Gemini parse failed: no quota buckets in API response")
            throw ProbeError.parseFailed("No quota buckets in response")
        }

        // Group quotas by model, keeping lowest per model
        var modelQuotaMap: [String: (fraction: Double, resetTime: String?)] = [:]

        for bucket in buckets {
            guard let modelId = bucket.modelId, let fraction = bucket.remainingFraction else { continue }

            if let existing = modelQuotaMap[modelId] {
                if fraction < existing.fraction {
                    modelQuotaMap[modelId] = (fraction, bucket.resetTime)
                }
            } else {
                modelQuotaMap[modelId] = (fraction, bucket.resetTime)
            }
        }

        let quotas: [UsageQuota] = modelQuotaMap
            .sorted { $0.key < $1.key }
            .map { modelId, data in
                let resetsAt = data.resetTime.flatMap { parseResetTime($0) }
                return UsageQuota(
                    percentRemaining: data.fraction * 100,
                    quotaType: .modelSpecific(modelId),
                    providerId: "gemini",
                    resetsAt: resetsAt,
                    resetText: formatResetText(resetsAt)
                )
            }

        guard !quotas.isEmpty else {
            AppLog.probes.error("Gemini parse failed: no valid quotas after processing buckets")
            throw ProbeError.parseFailed("No valid quotas found")
        }

        return UsageSnapshot(
            providerId: "gemini",
            quotas: quotas,
            capturedAt: Date()
        )
    }

    // MARK: - Credentials & Models

    private struct OAuthCredentials {
        let accessToken: String?
        let refreshToken: String?
        let expiryDate: Date?
    }

    private func loadCredentials() throws -> OAuthCredentials {
        #if MAS_BUILD
        if let bm = bookmarkManager {
            return try bm.withScopedAccess(folderID: BookmarkFolderID.gemini) {
                try self._loadCredentials()
            }
        }
        #endif
        return try _loadCredentials()
    }

    private func _loadCredentials() throws -> OAuthCredentials {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)

        guard FileManager.default.fileExists(atPath: credsURL.path) else {
            AppLog.probes.error("Gemini probe failed: credentials file not found")
            throw ProbeError.authenticationRequired
        }

        let data = try Data(contentsOf: credsURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            AppLog.probes.error("Gemini probe failed: invalid JSON in credentials file")
            throw ProbeError.parseFailed("Invalid credentials file")
        }

        let accessToken = json["access_token"] as? String
        let refreshToken = json["refresh_token"] as? String

        var expiryDate: Date?
        if let expiryMs = json["expiry_date"] as? Double {
            expiryDate = Date(timeIntervalSince1970: expiryMs / 1000)
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryDate: expiryDate
        )
    }

    // MARK: - Reset Time Parsing

    private func parseResetTime(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func formatResetText(_ date: Date?) -> String? {
        guard let date else { return nil }

        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return nil }

        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "Resets in \(minutes)m"
        } else {
            return "Resets soon"
        }
    }

    private struct QuotaBucket: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
        let modelId: String?
        let tokenType: String?
    }

    private struct QuotaResponse: Decodable {
        let buckets: [QuotaBucket]?
    }
}
