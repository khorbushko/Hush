import AppKit
import FluidMenuBarExtra
import SwiftUI

/// Application entry point: activates as a menu-bar agent and hosts the mixer in a ``FluidMenuBarExtra`` popup.
///
/// `LSUIElement` in Info.plist already keeps the app off the Dock; avoid ``NSApp.setActivationPolicy`` in `init()` because
/// SwiftUI’s synthesized ``App`` initializer runs before the shared application is fully ready and can destabilize launch.
///
/// The whole type is ``MainActor`` so ``StateObject`` construction stays on the UI actor; playback runs on ``AudioEngineService``’s
/// dedicated actor graph (same isolation split as SwiftUI + ``AVAudioEngine`` demos).
///
/// FluidMenuBarExtra replaces hand-rolled ``NSPopover`` wiring for sizing, dismissal, and system integration—see the
/// [FluidMenuBarExtra](https://github.com/wadetregaskis/FluidMenuBarExtra) package README.
///
/// The initial SF Symbol mirrors ``SoundMixerViewModel/isGloballyPlaying`` when the scene is constructed; afterward
/// ``HushMenuBarGlyphSync`` keeps the waveform / muted glyph in sync (the package rebuilds toolbar images only once).
@MainActor
@main
struct HushApp: App {
    @StateObject private var viewModel = SoundMixerViewModel(audio: AudioEngineService())
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
