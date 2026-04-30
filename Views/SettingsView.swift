import SwiftUI
import UserNotifications

/// Secondary surface for launch item, defaults, and notifications (embedded popover pane, not heap navigation chrome).
public struct SettingsView: View {
    @ObservedObject private var viewModel: SoundMixerViewModel
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.hushAccent) private var accent
    /// Returns to the mixer surface (``NavigationStack/dismiss()`` is unreliable inside menu-bar panels).
    private let onBack: () -> Void

    /// Presents the settings form with an explicit dismiss action.
    public init(viewModel: SoundMixerViewModel, onBack: @escaping () -> Void) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onBack = onBack
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .keyboardShortcut(.escape, modifiers: [])
                Text("Settings")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(label)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)

            Divider()
                .blendMode(.softLight)

            Form {
                Section("Session") {
                    Toggle("Launch at login", isOn: $viewModel.launchAtLoginEnabled)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default master volume")
                            .font(.subheadline.weight(.medium))
                        Slider(value: $viewModel.defaultMasterVolumeStored, in: 0 ... 1)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default timer")
                            .font(.subheadline.weight(.medium))
                        Picker("", selection: $viewModel.defaultTimerStored) {
                            ForEach(SleepTimerPreset.allCases) { preset in
                                Text(preset.menuTitle).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("Notifications") {
                    Toggle(
                        "Alert when timer completes",
                        isOn: Binding(
                            get: { viewModel.notifyOnTimerEnd },
                            set: { newValue in
                                viewModel.notifyOnTimerEnd = newValue
                                if newValue {
                                    Task {
                                        await Self.requestNotificationAuthorization()
                                    }
                                }
                            }
                        )
                    )
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.resetToFactoryDefaults()
                        onBack()
                    } label: {
                        Label("Reset to defaults", systemImage: "arrow.counterclockwise.circle")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(label)
    }
}

private extension SettingsView {
    static func requestNotificationAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
