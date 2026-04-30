import AppKit
import SwiftUI

/// Lightweight credits sheet surfaced from the popover toolbar.
public struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let accentColor: Color

    /// Presents attribution text and outbound marketing link.
    public init(accentColor: Color) {
        self.accentColor = accentColor
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                appIcon
                    .padding(.top, 4)
                Text("Hush")
                    .font(.title2.weight(.semibold))
                Text(bundleVersion)
                    .foregroundStyle(.secondary)
                Text("Crafted as a Sonoma-native ambient mixer that keeps focus soft and steady.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if let destination = URL(string: "https://example.com/hush") {
                    Link("Visit hushaudio.example.com", destination: destination)
                        .tint(accentColor)
                }
                Spacer()
            }
            .padding(24)
            .frame(minWidth: 320, minHeight: 260)
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.secondary, .quaternary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }
}

private extension AboutView {
    var appIcon: some View {
        Group {
            if let image =
                NSImage(named: NSImage.applicationIconName) ?? NSImage(named: "AppIcon") {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(accentColor.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
        }
    }

    var bundleVersion: String {
        let bundle = Bundle.main
        let marketing =
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "Version \(marketing) (\(build))"
    }
}
