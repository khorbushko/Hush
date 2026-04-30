import SwiftUI
import UserNotifications

public struct SettingsView: View {
    @Bindable private var viewModel: SoundMixerViewModel
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.hushAccent) private var accent
    private let onBack: () -> Void

    public init(viewModel: SoundMixerViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
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
                .accessibilityLabel(Text("settings.back"))
                .keyboardShortcut(.escape, modifiers: [])
                Text("settings.title")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(label)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)

            Divider()
                .blendMode(.softLight)

            Form {
                Section("settings.section.session") {
                    Toggle("settings.launch_at_login", isOn: $viewModel.launchAtLoginEnabled)
                    VStack {
                        Picker("settings.language", selection: $viewModel.appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.bottom, 8)

                        HStack {
                            Spacer()
                            Text("settings.language_restart_note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("settings.default_master_volume")
                            .font(.subheadline.weight(.medium))
                        Slider(value: $viewModel.defaultMasterVolumeStored, in: 0 ... 1)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.default_timer")
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

                Section("settings.section.notifications") {
                    Toggle(
                        "settings.alert_when_timer_completes",
                        isOn: Binding(
                            get: { viewModel.notifyOnTimerEnd },
                            set: { newValue in
                                viewModel.notifyOnTimerEnd = newValue
                                if newValue {
                                    Task { await Self.requestNotificationAuthorization() }
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
                        Label("settings.reset_defaults", systemImage: "arrow.counterclockwise.circle")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, -20)
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
