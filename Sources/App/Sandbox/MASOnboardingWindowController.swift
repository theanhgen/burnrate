#if MAS_BUILD
import AppKit
import SwiftUI
import Infrastructure

/// Opens and manages the guided folder-access onboarding window.
/// Uses the same NSWindow pattern as DetailWindowController — avoids
/// the popover-dismissal/NSOpenPanel race that sheets inside MenuBarExtra cause.
@MainActor
final class MASOnboardingWindowController {
    static let shared = MASOnboardingWindowController()

    private var window: NSWindow?

    func open(bookmarkManager: any BookmarkManaging, onComplete: @escaping @MainActor () -> Void) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = MASOnboardingView(
            bookmarkManager: bookmarkManager,
            onComplete: { [weak self] in
                onComplete()
                self?.window?.close()
            }
        )

        let hostingView = NSHostingView(rootView: onboardingView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "burnrate Setup"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .floating

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
    }

    func close() {
        window?.close()
    }
}
#endif
