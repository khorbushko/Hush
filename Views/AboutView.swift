import AppKit
import MarkdownView
import SwiftUI

/// Credits panel styled to match the app's popover chrome.
public struct AboutView: View {
    private let accentColor: Color

    public init(accentColor: Color) {
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Top metadata section — sits below the transparent title-bar traffic lights.
            VStack(spacing: 12) {
                appIcon
                Text("Hush")
                    .font(.title2.weight(.semibold))
                Text(bundleVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Ambient mixer that keeps focus soft and steady.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let destination = URL(string: "https://khorbushko.github.io") {
                    Link("Visit developer blog", destination: destination)
                        .font(.footnote)
                        .tint(accentColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)   // clears the transparent title-bar / traffic lights
            .padding(.bottom, 16)

            Divider()

            // Changelog — fills all remaining height with full Markdown rendering.
            if let markdown = changelogMarkdown {
                ScrollView {
                    MarkdownView(markdown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                Text("No changelog available.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        .frame(minWidth: 350, minHeight: 400)
        .background(.regularMaterial)
        .ignoresSafeArea()
    }
}

private extension AboutView {
    var appIcon: some View {
        Group {
            if let image = NSImage(named: NSImage.applicationIconName) ?? NSImage(named: "AppIcon") {
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
        let marketing = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "Version \(marketing) (\(build))"
    }

    var changelogMarkdown: String? {
        let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md")
            ?? Bundle.main.url(forResource: "CHANGELOG.md", withExtension: nil)
        guard let url,
              let raw = try? String(contentsOf: url, encoding: .utf8),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return raw
    }
}
