import SwiftUI

public struct CategorySectionView: View {
    private let category: SoundCategory
    private let sounds: [Sound]
    private let viewModel: SoundMixerViewModel
    @Environment(\.hushPrimaryLabel) private var label

    public init(
        category: SoundCategory,
        sounds: [Sound],
        viewModel: SoundMixerViewModel
    ) {
        self.category = category
        self.sounds = sounds
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.displayName)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(label)
            VStack(spacing: 0) {
                ForEach(sounds) { sound in
                    SoundRowView(sound: sound, viewModel: viewModel)
                    if sound.id != sounds.last?.id {
                        Divider().padding(.leading, 30)
                    }
                }
            }
        }
    }
}
