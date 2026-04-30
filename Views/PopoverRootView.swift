import AppKit
import SwiftUI

/// Hosts the entire SwiftUI hierarchy shown inside the status-item popover.
public struct PopoverRootView: View {
    /// `@Bindable` exposes `$viewModel.property` binding syntax for an `@Observable` object.
    @Bindable private var viewModel: SoundMixerViewModel
    @AppStorage("colorScheme") private var storedScheme = "system"
    @State private var showSettings = false
    @State private var clock = Date()
    @Environment(\.colorScheme) private var resolvedSystemScheme

    public init(viewModel: SoundMixerViewModel) {
        self.viewModel = viewModel
    }

    var height: CGFloat {
        showSettings ? 450 : 540
    }

    public var body: some View {
        Group {
            if showSettings {
                SettingsView(viewModel: viewModel) {
                    showSettings = false
                }
                .padding(16)
            } else {
                mixerPanel
                    .padding(16)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(chromeMaterial)
                .shadow(
                    color: Color.black.opacity(effectiveColorScheme == .dark ? 0.45 : 0.12),
                    radius: 16,
                    y: 6
                )
        }
        .frame(width: 320, height: height)
        .preferredColorScheme(effectiveSwiftUIScheme)
        .environment(\.hushAccent, hushChromeAccent(for: effectiveColorScheme))
        .environment(\.hushPrimaryLabel, primaryText(for: effectiveColorScheme))
        .tint(hushChromeAccent(for: effectiveColorScheme))
        .onReceive(Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common).autoconnect()) {
            clock = $0
        }
        .onReceive(NotificationCenter.default.publisher(for: .hushReloadStoredChrome)) { _ in
            storedScheme = "system"
        }
        .onDisappear {
            showSettings = false
        }
    }
}

private extension PopoverRootView {
    var mixerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(
                viewModel: viewModel,
                clock: $clock,
                onOpenSettings: { showSettings = true },
                onToggleTheme: cycleTheme,
                onOpenAbout: {
                    AboutWindowManager.open(accentColor: hushChromeAccent(for: effectiveColorScheme))
                },
                onQuit: scheduleTerminate
            )
            if viewModel.isAudioReady, missingBundledSoundTitles.isEmpty == false {
                missingAssetsBanner
            }
            masterVolumeRow
            TimerView(viewModel: viewModel)
                .padding(.top, 4)
            Divider()
                .blendMode(.softLight)
            scrollContent
                .padding(.bottom, 6)
        }
    }

    var chromeMaterial: Material {
        effectiveColorScheme == .dark ? .ultraThinMaterial : .regularMaterial
    }

    var missingBundledSoundTitles: [String] {
        Sound.library.filter { !viewModel.isBufferAvailable(for: $0.id) }.map(\.name)
    }

    var missingAssetsBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(
                    "Some audio files were not found or could not be decoded. Rebuild after adding matching `.m4a` files to the target (see `Sound.resourceName`)."
                )
                .font(.caption)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            Text("Missing: \(missingBundledSoundTitles.sorted().joined(separator: ", "))")
                .font(.caption2)
                .foregroundStyle(primaryText(for: effectiveColorScheme).opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    hushChromeAccent(for: effectiveColorScheme)
                        .opacity(effectiveColorScheme == .dark ? 0.22 : 0.18)
                )
        )
        .accessibilityElement(children: .combine)
    }

    var masterVolumeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Master volume")
                .font(.footnote.weight(.medium))
                .foregroundStyle(primaryText(for: effectiveColorScheme).opacity(0.75))
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(primaryText(for: effectiveColorScheme).opacity(0.55))
                    .font(.footnote)
                Slider(value: $viewModel.masterVolume, in: 0 ... 1)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(primaryText(for: effectiveColorScheme).opacity(0.55))
                    .font(.footnote)
            }
        }
        .foregroundStyle(primaryText(for: effectiveColorScheme))
    }

    var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(SoundCategory.allCases) { category in
                    let soundsForCategory = Sound.library.filter { $0.category == category }
                    if soundsForCategory.isEmpty == false {
                        CategorySectionView(
                            category: category,
                            sounds: soundsForCategory,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    var effectiveColorScheme: ColorScheme {
        switch storedScheme {
        case "light": return .light
        case "dark": return .dark
        default: return resolvedSystemScheme
        }
    }

    var effectiveSwiftUIScheme: ColorScheme? {
        switch storedScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func cycleTheme() {
        switch storedScheme {
        case "system":
            storedScheme = "light"
        case "light":
            storedScheme = "dark"
        default:
            storedScheme = "system"
        }
    }

    func scheduleTerminate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: – Theme helpers

private enum HushTheme {
    static let sand = Color(red: 0.784, green: 0.663, blue: 0.494)
    static let amberNight = Color(red: 0.910, green: 0.722, blue: 0.427)
    static let textLight = Color(red: 0.110, green: 0.110, blue: 0.118)
}

private func hushChromeAccent(for scheme: ColorScheme) -> Color {
    scheme == .dark ? HushTheme.amberNight : HushTheme.sand
}

private func primaryText(for scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.primary : HushTheme.textLight
}

// MARK: – Environment keys

struct HushAccentKey: EnvironmentKey {
    static let defaultValue: Color = HushTheme.sand
}

struct HushPrimaryKey: EnvironmentKey {
    static let defaultValue: Color = .primary
}

extension EnvironmentValues {
    var hushAccent: Color {
        get { self[HushAccentKey.self] }
        set { self[HushAccentKey.self] = newValue }
    }

    var hushPrimaryLabel: Color {
        get { self[HushPrimaryKey.self] }
        set { self[HushPrimaryKey.self] = newValue }
    }
}
