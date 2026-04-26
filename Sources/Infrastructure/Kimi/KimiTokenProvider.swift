import Foundation
#if !MAS_BUILD
import SweetCookieKit
#endif
import Domain

/// Protocol for resolving Kimi authentication tokens.
/// Enables testability by allowing mock implementations.
public protocol KimiTokenProviding: Sendable {
    func resolveToken() throws -> String
}

/// Resolves Kimi authentication token from environment variable or browser cookies.
///
/// Resolution order:
/// 1. `KIMI_AUTH_TOKEN` environment variable
/// 2. `kimi-auth` cookie from browser cookie stores (via SweetCookieKit) -- non-MAS only
public struct KimiCookieTokenProvider: KimiTokenProviding {
    public init() {}

    public func resolveToken() throws -> String {
        // 1. Check environment variable
        if let envToken = ProcessInfo.processInfo.environment["KIMI_AUTH_TOKEN"],
           !envToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            AppLog.probes.debug("Kimi: Using token from KIMI_AUTH_TOKEN env var")
            return envToken
        }

        #if !MAS_BUILD
        // 2. Try extracting from browser cookies
        if let browserToken = fetchFromBrowser() {
            AppLog.probes.debug("Kimi: Using token from browser cookie")
            return browserToken
        }
        #endif

        AppLog.probes.error("Kimi: No authentication token found")
        throw ProbeError.authenticationRequired
    }

    #if !MAS_BUILD
    private func fetchFromBrowser() -> String? {
        let cookieClient = BrowserCookieClient()
        let query = BrowserCookieQuery(
            domains: ["www.kimi.com", "kimi.com"],
            domainMatch: .suffix,
            includeExpired: false
        )

        for browser in Browser.defaultImportOrder {
            do {
                let stores = try cookieClient.records(matching: query, in: browser)
                for store in stores {
                    let cookies = store.cookies(origin: query.origin)
                    if let auth = cookies.first(where: { $0.name == "kimi-auth" }),
                       !auth.value.isEmpty
                    {
                        return auth.value
                    }
                }
            } catch {
                continue
            }
        }
        return nil
    }
    #endif
}
