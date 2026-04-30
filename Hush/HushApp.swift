import AppKit
import FluidMenuBarExtra
import SwiftUI

@MainActor
@main
struct HushApp: App {
    @State private var viewModel = SoundMixerViewModel(audio: AudioEngineService())
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
