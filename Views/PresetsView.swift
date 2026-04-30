import SwiftUI

/// Horizontal strip of saved sound-mix presets.
///
/// Layout: `[← scrollable cards →] [🎲] [+]`
/// — the two action buttons are pinned to the right edge, outside the scroll view.
public struct PresetsView: View {
    let viewModel: SoundMixerViewModel

    @Environment(\.hushAccent) private var accent
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.colorScheme) private var colorScheme

    // Expanded by default so presets are immediately visible on launch.
    @State private var isExpanded = true

    public init(viewModel: SoundMixerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ExpandableView(
            "Presets",
            isExpanded: $isExpanded,
            style: ExpandableStyle(
                titleColor: label.opacity(0.75),
                chevronColor: label.opacity(0.45)
            )
        ) {
            HStack(alignment: .center, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(viewModel.presets) { preset in
                            Button {
                                guard viewModel.isAudioReady else { return }
                                viewModel.loadPreset(preset)
                            } label: {
                                PresetCard(preset: preset, colorScheme: colorScheme)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.deletePreset(preset)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    randomButton
                    addButton
                    stopAllButton
                }
            }
            .frame(height: 40)
        }
    }
}

// MARK: – Fixed action buttons

private extension PresetsView {
    private static let buttonSize: CGFloat = 32

    var addButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.saveCurrentAsPreset()
            }
        } label: {
            Image(systemName: "plus.app.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(
                    accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isGloballyPlaying)
        .opacity(viewModel.isGloballyPlaying ? 1 : 0.35)
        .accessibilityLabel("Save current mix as preset")
    }

    var randomButton: some View {
        Button {
            guard viewModel.isAudioReady else { return }
            viewModel.randomizeMix()
        } label: {
            Image(systemName: "dice.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(
                    accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isAudioReady)
        .opacity(viewModel.isAudioReady ? 1 : 0.35)
        .accessibilityLabel("Randomise current mix")
    }

    var stopAllButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.stopAllSounds()
            }
        } label: {
            Image(systemName: "stop.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(
                    accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isGloballyPlaying)
        .opacity(viewModel.isGloballyPlaying ? 1 : 0.35)
        .accessibilityLabel("Stop all sounds")
    }
}

// MARK: – Preset card

/// A single saved-preset tile at 32 × 32 pt.
private struct PresetCard: View {
    let preset: SoundPreset
    let colorScheme: ColorScheme

    private static let size: CGFloat = 32
    private static let cornerRadius: CGFloat = 8

    var body: some View {
        symbolGrid
            .frame(width: Self.size, height: Self.size)
            .background(cardColor, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .accessibilityLabel("Preset with \(preset.symbolNames.count) sound\(preset.symbolNames.count == 1 ? "" : "s")")
            .accessibilityHint("Tap to load, hold to delete")
    }

    private var cardColor: Color {
        Color(
            hue: preset.hue,
            saturation: colorScheme == .dark ? 0.30 : 0.22,
            brightness: colorScheme == .dark ? 0.45 : 0.95
        )
    }

    private var fg: Color { Color.primary.opacity(0.72) }

    @ViewBuilder
    private var symbolGrid: some View {
        let names = Array(preset.symbolNames.prefix(4))
        let extra = max(0, preset.symbolNames.count - 4)

        switch names.count {
        case 1:
            Image(systemName: names[0])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(fg)

        case 2:
            HStack(spacing: 2) {
                ForEach(names, id: \.self) {
                    Image(systemName: $0)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(fg)
                }
            }

        default:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(names.prefix(2), id: \.self) {
                        Image(systemName: $0)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(fg)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(names.dropFirst(2), id: \.self) {
                        Image(systemName: $0)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(fg)
                    }
                    if extra > 0 {
                        Text("+\(extra)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(fg.opacity(0.7))
                    }
                }
            }
        }
    }
}
