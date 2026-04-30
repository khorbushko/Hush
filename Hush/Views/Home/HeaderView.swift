import AppKit
import SwiftUI

public struct HeaderView: View {
    private let viewModel: SoundMixerViewModel
    @Binding private var clock: Date
    @AppStorage("colorScheme") private var storedScheme = "system"
    private let onOpenSettings: () -> Void
    private let onOpenCoffee: () -> Void
    private let onBugReport: () -> Void
    private let onToggleTheme: () -> Void
    private let onOpenAbout: () -> Void
    private let onQuit: () -> Void

    @Environment(\.hushAccent) private var accent
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.locale) private var locale

    public init(
        viewModel: SoundMixerViewModel,
        clock: Binding<Date>,
        onOpenSettings: @escaping () -> Void,
        onOpenCoffee: @escaping () -> Void,
        onToggleTheme: @escaping () -> Void,
        onOpenAbout: @escaping () -> Void,
        onBugReport: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        _clock = clock
        self.onOpenSettings = onOpenSettings
        self.onOpenCoffee = onOpenCoffee
        self.onToggleTheme = onToggleTheme
        self.onOpenAbout = onOpenAbout
        self.onBugReport = onBugReport
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                appGlyph
                VStack(alignment: .leading, spacing: 2) {
                    Text("app.name")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(label)
                    Text(versionLine)
                        .font(.caption2)
                        .foregroundStyle(label.opacity(0.55))
                }
                Spacer()


                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        iconButton("gearshape.fill", action: onOpenSettings)
                        iconButton(themeSymbol, action: onToggleTheme)
                        iconButton("info.circle", action: onOpenAbout)
                        iconButton("power", action: onQuit)
                    }
                    HStack {
                        Spacer()
                        iconButton("cup.and.saucer.fill", accessibilityKey: "header.coffee_support", action: onOpenCoffee)
                        iconButton("ladybug", action: onBugReport)
                    }
                }
                .frame(height: 50)
            }
            if let countdown = viewModel.formattedCountdown(referenceDate: clock),
               viewModel.timerEndsAt != nil {
                (Text("header.timer_prefix") + Text(" ") + Text(countdown).monospacedDigit())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
    }
}

private extension HeaderView {
    var versionLine: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return String.localizedStringWithFormat(
            String(localized: "common.version_format", locale: locale),
            version
        )
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

    func iconButton(
        _ systemName: String,
        accessibilityKey: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(label.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(Circle().fill(.thinMaterial.opacity(0.95)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityKey.map(Text.init) ?? Text(systemName))
    }
}

private enum BundleIcon {
    static var fallbackDockIcon: NSImage? {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}
