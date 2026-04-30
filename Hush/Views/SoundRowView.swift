import SwiftUI

/// Renders toggles and level controls for a catalogued sound.
public struct SoundRowView: View {
    private let sound: Sound
    private let viewModel: SoundMixerViewModel
    @Environment(\.hushAccent) private var accent
    @Environment(\.hushPrimaryLabel) private var label

    public init(sound: Sound, viewModel: SoundMixerViewModel) {
        self.sound = sound
        self.viewModel = viewModel
    }

    private var runtime: SoundTrackRuntime {
        viewModel.tracks[sound.id] ?? SoundTrackRuntime(isEnabled: false, normalizedVolume: 0.5)
    }

    private var hasBuffer: Bool {
        viewModel.isBufferAvailable(for: sound.id)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: sound.symbolName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(accent)
                    .frame(width: 26, alignment: .center)
                    .opacity(hasBuffer ? 1 : 0.35)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(label)
                    if hasBuffer == false {
                        Text("Asset missing")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { runtime.isEnabled },
                    set: { viewModel.setEnabled($0, for: sound.id) }
                ))
                .labelsHidden()
                .disabled(!viewModel.isAudioReady || !hasBuffer)
            }
            HStack(spacing: 8) {
                Text("0%")
                    .font(.caption2)
                    .foregroundStyle(label.opacity(0.45))
                Slider(
                    value: Binding(
                        get: { runtime.normalizedVolume },
                        set: { viewModel.setVolume($0, for: sound.id) }
                    ),
                    in: 0 ... 1
                )
                Text("100%")
                    .font(.caption2)
                    .foregroundStyle(label.opacity(0.45))
            }
            .opacity(runtime.isEnabled ? 1 : 0.65)
        }
        .padding(.vertical, 8)
    }
}
