import SwiftUI
import AppKit
import Domain

@MainActor
final class DetailWindowController {
    static let shared = DetailWindowController()

    private var window: NSWindow?

    func open(monitor: QuotaMonitor, sessionMonitor: SessionMonitor, provider: String? = nil) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let detailView = DetailView(monitor: monitor, sessionMonitor: sessionMonitor, initialProvider: provider)
        let hostingView = NSHostingView(rootView: detailView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 1200),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "burnrate — Details"
        w.contentView = hostingView
        w.center()
        w.setFrameAutosaveName("BurnRateDetail")
        w.minSize = NSSize(width: 520, height: 400)
        w.isReleasedWhenClosed = false

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
    }
}
