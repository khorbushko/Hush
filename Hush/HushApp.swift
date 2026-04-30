import AppKit
import FluidMenuBarExtra
import SwiftUI

/// Application entry point: activates as a menu-bar agent and hosts the mixer in a ``FluidMenuBarExtra`` popup.
///
/// `LSUIElement` in Info.plist already keeps the app off the Dock; avoid ``NSApp.setActivationPolicy`` in `init()` because
/// SwiftUI's synthesized ``App`` initializer runs before the shared application is fully ready and can destabilize launch.
///
/// `@State` wrapping an `@Observable` class lets SwiftUI own the instance for the app lifetime and automatically
/// track property accesses — the `@Observable` + `@State` pair replaces the older `ObservableObject` + `@StateObject` pattern.
///
/// Playback itself runs on ``AudioEngineService``'s dedicated actor graph, keeping audio I/O off the main actor.
///
/// FluidMenuBarExtra replaces hand-rolled ``NSPopover`` wiring for sizing, dismissal, and system integration — see the
/// [FluidMenuBarExtra](https://github.com/wadetregaskis/FluidMenuBarExtra) package README.
@MainActor
@main
struct HushApp: App {
    @State private var viewModel = SoundMixerViewModel(audio: AudioEngineService())
    /// Bound so Command-drag removal of the item persists per the package contract.
    @AppStorage("hush.menuBarExtraInserted") private var menuBarExtraInserted = true

    var body: some Scene {
        FluidMenuBarExtra(
            "Hush",
            systemImage: viewModel.isGloballyPlaying ? "waveform" : "waveform.slash",
            isInserted: $menuBarExtraInserted,
            animation: .none,
            alignment: .left,
            screenClippingBehaviour: .reverseAlignment
        ) {
            PopoverRootView(viewModel: viewModel)
        }
    }
}
