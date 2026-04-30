import AppKit
import SwiftUI

/// Top chrome with branding, timer readout, and quick actions.
public struct HeaderView: View {
    @ObservedObject private var viewModel: SoundMixerViewModel
    @Binding private var clock: Date
    @AppStorage("colorScheme") private var storedScheme = "system"
    private let onOpenSettings: () -> Void
    private let onToggleTheme: () -> Void
    private let onOpenAbout: () -> Void
    private let onQuit: () -> Void

    @Environment(\.hushAccent) private var accent
    @Environment(\.hushPrimaryLabel) private var label

    /// Hosts the marquee row for the popover.
    public init(
        viewModel: SoundMixerViewModel,
        clock: Binding<Date>,
        onOpenSettings: @escaping () -> Void,
        onToggleTheme: @escaping () -> Void,
        onOpenAbout: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _clock = clock
        self.onOpenSettings = onOpenSettings
        self.onToggleTheme = onToggleTheme
        self.onOpenAbout = onOpenAbout
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                appGlyph
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hush")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(label)
                    Text(versionLine)
                        .font(.caption2)
                        .foregroundStyle(label.opacity(0.55))
                }
                Spacer()
                iconButton("gearshape.fill", action: onOpenSettings)
                iconButton(themeSymbol, action: onToggleTheme)
                iconButton("info.circle", action: onOpenAbout)
                iconButton("power", action: onQuit)
            }
            if let countdown = viewModel.formattedCountdown(referenceDate: clock),
               viewModel.timerEndsAt != nil {
                Text("Timer \(Text(countdown).monospacedDigit())")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
    }
}

private extension HeaderView {
    var versionLine: String {
        let bundle = Bundle.main
        let version =
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "Version \(version)"
    }

    var appGlyph: some View {
        Group {
            if let image = NSImage(named: NSImage.applicationIconName)
                ?? NSImage(named: "AppIcon")
                ?? BundleIcon.fallbackDockIcon {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(accent)
            }
        }
    }

    var themeSymbol: String {
        switch storedScheme {
        case "light": return "sun.max.fill"
        case "dark": return "moon.stars.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(label.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.thinMaterial.opacity(0.95))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName))
    }
}

private enum BundleIcon {
    /// Used only when catalog / application icon blobs are unavailable in this process.
    static var fallbackDockIcon: NSImage? {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}
