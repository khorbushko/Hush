import AppKit
import SwiftUI

/// Opens ``AboutView`` in a standalone floating panel that is independent of the popover.
///
/// The panel uses a transparent title bar so the standard macOS close button remains visible
/// while the SwiftUI material fills the entire window — matching the popover's visual style.
@MainActor
enum AboutWindowManager {
    private static weak var panel: NSPanel?

    /// Opens the About panel, or brings the existing one to front if already visible.
    static func open(accentColor: Color) {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = AboutView(accentColor: accentColor)
        let hosting = NSHostingController(rootView: content)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.contentViewController = hosting
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.isMovableByWindowBackground = true
        newPanel.isReleasedWhenClosed = false
        newPanel.level = .floating
        newPanel.center()

        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
