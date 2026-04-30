import SwiftUI

/// Sleep timer controls surfaced under the master fader.
///
/// Wraps ``ExpandableView`` and auto-collapses when the active timer ends.
public struct TimerView: View {
    @Bindable private var viewModel: SoundMixerViewModel
    @Environment(\.hushPrimaryLabel) private var label
    @Environment(\.hushAccent) private var accent

    @State private var isExpanded = false

    public init(viewModel: SoundMixerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ExpandableView(
            "Sleep timer",
            isExpanded: $isExpanded,
            style: ExpandableView.Style(
                titleColor: label.opacity(0.75),
                chevronColor: label.opacity(0.45)
            )
        ) {
            controls
        }
        // No `withAnimation` needed — ExpandableView's implicit animation on `isExpanded`
        // handles the collapse transition uniformly whether triggered by tap or timer end.
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

    var customSelectionInvalid: Bool {
        viewModel.timerPreset == .custom && viewModel.customTimerMinutesTotal <= 0
    }
}
