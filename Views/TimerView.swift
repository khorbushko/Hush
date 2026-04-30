import SwiftUI

/// Sleep timer controls surfaced under the master fader.
public struct TimerView: View {
    /// `@Bindable` exposes `$viewModel.timerPreset` binding syntax for an `@Observable` object.
    @Bindable private var viewModel: SoundMixerViewModel
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.hushAccent) private var accent

    public init(viewModel: SoundMixerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep timer")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(label.opacity(0.75))
            Picker("Preset", selection: $viewModel.timerPreset) {
                ForEach(SleepTimerPreset.allCases) { preset in
                    Text(preset.menuTitle).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.timerPreset == .custom {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Picker("Hours", selection: Binding(
                        get: { viewModel.customTimerHourComponent },
                        set: { viewModel.setCustomTimerComponents(hours: $0, minutes: viewModel.customTimerMinuteComponent) }
                    )) {
                        ForEach(0 ... 5, id: \.self) { hour in
                            Text("\(hour) h").tag(hour)
                        }
                    }
                    .labelsHidden()
                    Picker("Minutes", selection: Binding(
                        get: { viewModel.customTimerMinuteComponent },
                        set: { viewModel.setCustomTimerComponents(hours: viewModel.customTimerHourComponent, minutes: $0) }
                    )) {
                        ForEach(0 ..< 60, id: \.self) { minute in
                            Text(String(format: "%02d m", minute)).tag(minute)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }

            HStack {
                Button("Stop countdown") {
                    viewModel.cancelTimer()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.timerEndsAt == nil)

                Spacer()

                Button {
                    viewModel.startTimer()
                } label: {
                    Label("Start timer", systemImage: "timer")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(viewModel.timerPreset == .disabled || customSelectionInvalid)
            }
        }
    }
}

private extension TimerView {
    var customSelectionInvalid: Bool {
        viewModel.timerPreset == .custom && viewModel.customTimerMinutesTotal <= 0
    }
}
