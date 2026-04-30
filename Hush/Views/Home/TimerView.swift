import SwiftUI

/// Sleep timer controls surfaced under the master fader.
///
/// Wraps ``ExpandableView`` and auto-collapses when the active timer ends.
public struct TimerView: View {
    @Bindable private var viewModel: SoundMixerViewModel
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.hushAccent) private var accent
    @Environment(\.locale) private var locale

    @State private var isExpanded = false

    public init(viewModel: SoundMixerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ExpandableView(
            "timer.title",
            isExpanded: $isExpanded,
            style: ExpandableStyle(
                titleColor: label.opacity(0.75),
                chevronColor: label.opacity(0.45)
            )
        ) {
            controls
        }
        .onChange(of: viewModel.timerEndsAt) { _, newValue in
            if newValue == nil {
                isExpanded = false
            }
        }
    }
}

private extension TimerView {
    var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("timer.preset", selection: $viewModel.timerPreset) {
                ForEach(SleepTimerPreset.allCases) { preset in
                    Text(preset.menuTitle).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.timerPreset == .custom {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Picker("timer.hours", selection: Binding(
                        get: { viewModel.customTimerHourComponent },
                        set: { viewModel.setCustomTimerComponents(hours: $0, minutes: viewModel.customTimerMinuteComponent) }
                    )) {
                        ForEach(0 ... 5, id: \.self) { hour in
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "timer.hours_short_format", locale: locale),
                                    hour
                                )
                            )
                            .tag(hour)
                        }
                    }
                    .labelsHidden()
                    Picker("timer.minutes", selection: Binding(
                        get: { viewModel.customTimerMinuteComponent },
                        set: { viewModel.setCustomTimerComponents(hours: viewModel.customTimerHourComponent, minutes: $0) }
                    )) {
                        ForEach(0 ..< 60, id: \.self) { minute in
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "timer.minutes_short_format", locale: locale),
                                    minute
                                )
                            )
                            .tag(minute)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }

            HStack {
                Button("timer.stop_countdown") {
                    viewModel.cancelTimer()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.timerEndsAt == nil)

                Spacer()

                Button {
                    viewModel.startTimer()
                } label: {
                    Label("timer.start_timer", systemImage: "timer")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(viewModel.timerPreset == .disabled || customSelectionInvalid)
            }
        }
    }

    var customSelectionInvalid: Bool {
        viewModel.timerPreset == .custom && viewModel.customTimerMinutesTotal <= 0
    }
}
