import AppKit

/// FluidMenuBarExtra applies the toolbar symbol once when ``NSStatusItem`` is constructed; SwiftUI `@StateObject` preserves
/// that item while recomputing scenes, so this helper reapplies glyphs when playback state toggles (via status-bar hierarchy).
enum HushMenuBarGlyphSync {
    private static let accessibilityTitle = "Hush"

    /// Reapplies the waveform / waveform.slash symbol for our item, retrying briefly until Fluid has created the `NSStatusItem`.
    @MainActor
    static func schedule(isPlaying: Bool, retriesRemaining: Int = 8) {
        guard let image = NSImage(
            systemSymbolName: isPlaying ? "waveform" : "waveform.slash",
            accessibilityDescription: accessibilityTitle
        ) else {
            return
        }

        guard let button = statusBarButton(matchingAccessibilityTitle: accessibilityTitle) else {
            guard retriesRemaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                schedule(isPlaying: isPlaying, retriesRemaining: retriesRemaining - 1)
            }
            return
        }

        button.image = image
    }

    private static func statusBarButton(matchingAccessibilityTitle needle: String) -> NSStatusBarButton? {
        for window in NSApp.windows where window.level == .statusBar {
            let buttons = collectStatusBarButtons(in: window.contentView)
            if let match = buttons.first(where: { matchesAccessibility($0, needle: needle) }) {
                return match
            }
            if buttons.count == 1 {
                return buttons.first
            }
        }
        return nil
    }

    private static func matchesAccessibility(_ button: NSStatusBarButton, needle: String) -> Bool {
        // NSObject KVC avoids Swift ambiguity between dynamic `accessibilityTitle` selectors on `NSStatusBarButton`.
        let axTitle = button.value(forKey: "accessibilityTitle") as? String
        let axLabel = button.value(forKey: "accessibilityLabel") as? String
        return axTitle == needle || axLabel == needle
    }

    private static func collectStatusBarButtons(in root: NSView?) -> [NSStatusBarButton] {
        guard let root else { return [] }
        var collected: [NSStatusBarButton] = []
        func visit(_ view: NSView) {
            if let barButton = view as? NSStatusBarButton {
                collected.append(barButton)
            }
            for sub in view.subviews {
                visit(sub)
            }
        }
        visit(root)
        return collected
    }
}
