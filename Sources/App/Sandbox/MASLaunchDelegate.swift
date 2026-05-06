#if MAS_BUILD
import AppKit
import Infrastructure

/// NSApplicationDelegate that fires the MAS onboarding window at app launch,
/// before the user has clicked the menu bar icon.
///
/// Wired into BurnrateApp via @NSApplicationDelegateAdaptor.
/// SwiftUI forwards applicationDidFinishLaunching to this delegate while
/// continuing to own the scene graph.
@MainActor
final class MASLaunchDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bookmarkManager = SecurityScopedBookmarkManager()
        let onboardingManager = MASOnboardingManager(bookmarkManager: bookmarkManager)
        guard onboardingManager.shouldShowOnboarding else { return }

        MASOnboardingWindowController.shared.open(bookmarkManager: bookmarkManager) {
            // Create a fresh manager to write the flag (UserDefaults-backed, no shared state needed)
            MASOnboardingManager(bookmarkManager: SecurityScopedBookmarkManager()).markComplete()
        }
    }
}
#endif
