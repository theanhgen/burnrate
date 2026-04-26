import Foundation
import Mockable
@testable import Domain

/// Shared test helper factory for creating mock/test repositories
/// Eliminates duplication across provider tests (CopilotProvider, ZaiProvider, etc.)
struct MockRepositoryFactory {

    /// Creates a mock settings repository for provider tests (base ProviderSettingsRepository)
    /// - Parameter enabled: Whether the provider is enabled (defaults to true)
    /// - Returns: A configured MockProviderSettingsRepository
    static func makeSettingsRepository(enabled: Bool = true) -> MockProviderSettingsRepository {
        let mock = MockProviderSettingsRepository()
        given(mock).isEnabled(forProvider: .any, defaultValue: .any).willReturn(enabled)
        given(mock).isEnabled(forProvider: .any).willReturn(enabled)
        given(mock).setEnabled(.any, forProvider: .any).willReturn()
        given(mock).customCardURL(forProvider: .any).willReturn(nil)
        given(mock).setCustomCardURL(.any, forProvider: .any).willReturn()
        return mock
    }

    /// Creates a Z.ai settings repository mock for tests
    /// - Parameter enabled: Whether the provider is enabled (defaults to true)
    /// - Parameter zaiConfigPath: The Z.ai config path
    /// - Parameter glmAuthEnvVar: The GLM auth env var
    /// - Returns: A configured MockZaiSettingsRepository
    static func makeZaiSettingsRepository(
        enabled: Bool = true,
        zaiConfigPath: String = "",
        glmAuthEnvVar: String = ""
    ) -> MockZaiSettingsRepository {
        let mock = MockZaiSettingsRepository()
        given(mock).isEnabled(forProvider: .any, defaultValue: .any).willReturn(enabled)
        given(mock).isEnabled(forProvider: .any).willReturn(enabled)
        given(mock).setEnabled(.any, forProvider: .any).willReturn()
        given(mock).customCardURL(forProvider: .any).willReturn(nil)
        given(mock).setCustomCardURL(.any, forProvider: .any).willReturn()
        given(mock).zaiConfigPath().willReturn(zaiConfigPath)
        given(mock).setZaiConfigPath(.any).willReturn()
        given(mock).glmAuthEnvVar().willReturn(glmAuthEnvVar)
        given(mock).setGlmAuthEnvVar(.any).willReturn()
        return mock
    }

    /// Creates a Copilot settings repository mock for tests with stateful credential storage
    /// - Parameter enabled: Whether the provider is enabled (defaults to false for Copilot)
    /// - Parameter copilotAuthEnvVar: The Copilot auth env var
    /// - Parameter username: The GitHub username (empty = none)
    /// - Parameter hasToken: Whether a token is saved
    /// - Returns: A configured MockCopilotSettingsRepository
    static func makeCopilotSettingsRepository(
        enabled: Bool = false,
        copilotAuthEnvVar: String = "",
        username: String = "",
        hasToken: Bool = false
    ) -> MockCopilotSettingsRepository {
        let mock = MockCopilotSettingsRepository()

        // Base protocol
        given(mock).isEnabled(forProvider: .any, defaultValue: .any).willReturn(enabled)
        given(mock).isEnabled(forProvider: .any).willReturn(enabled)
        given(mock).setEnabled(.any, forProvider: .any).willReturn()
        given(mock).customCardURL(forProvider: .any).willReturn(nil)
        given(mock).setCustomCardURL(.any, forProvider: .any).willReturn()

        // Probe mode (stateful)
        var probeMode: CopilotProbeMode = .billing
        given(mock).copilotProbeMode().willProduce { probeMode }
        given(mock).setCopilotProbeMode(.any).willProduce { probeMode = $0 }

        // Auth env var
        given(mock).copilotAuthEnvVar().willReturn(copilotAuthEnvVar)
        given(mock).setCopilotAuthEnvVar(.any).willReturn()

        // Monthly limit
        given(mock).copilotMonthlyLimit().willReturn(nil)
        given(mock).setCopilotMonthlyLimit(.any).willReturn()

        // Manual usage override
        given(mock).copilotManualUsageValue().willReturn(nil)
        given(mock).setCopilotManualUsageValue(.any).willReturn()
        given(mock).copilotManualUsageIsPercent().willReturn(false)
        given(mock).setCopilotManualUsageIsPercent(.any).willReturn()
        given(mock).copilotManualOverrideEnabled().willReturn(false)
        given(mock).setCopilotManualOverrideEnabled(.any).willReturn()
        given(mock).copilotApiReturnedEmpty().willReturn(false)
        given(mock).setCopilotApiReturnedEmpty(.any).willReturn()

        // Usage period tracking
        given(mock).copilotLastUsagePeriodMonth().willReturn(nil)
        given(mock).copilotLastUsagePeriodYear().willReturn(nil)
        given(mock).setCopilotLastUsagePeriod(month: .any, year: .any).willReturn()

        // Credentials (stateful)
        var storedToken: String? = hasToken ? "test-token" : nil
        given(mock).saveGithubToken(.any).willProduce { storedToken = $0 }
        given(mock).getGithubToken().willProduce { storedToken }
        given(mock).deleteGithubToken().willProduce { storedToken = nil }
        given(mock).hasGithubToken().willProduce { storedToken != nil }

        var storedUsername: String? = username.isEmpty ? nil : username
        given(mock).saveGithubUsername(.any).willProduce { storedUsername = $0 }
        given(mock).getGithubUsername().willProduce { storedUsername }
        given(mock).deleteGithubUsername().willProduce { storedUsername = nil }

        return mock
    }
}
