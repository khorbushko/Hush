import Foundation

public struct Sound: Identifiable, Hashable, Sendable {
    /// Stable identifier used for persistence and audio routing.
    public let id: String
    /// Localized name shown in the mixer UI.
    public let name: LocalizedStringResource
    /// Section the sound belongs to.
    public let category: SoundCategory
    /// Base filename in `Resources/Audio` (copied into the bundle; may flatten to `.m4a` at the bundle root).
    public let resourceName: String
    /// SF Symbol name displayed next to the track.
    public let symbolName: String

    /// Creates a sound definition for the library catalog.
    public init(
        id: String,
        name: LocalizedStringResource,
        category: SoundCategory,
        resourceName: String,
        symbolName: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.resourceName = resourceName
        self.symbolName = symbolName
    }

    public static func == (lhs: Sound, rhs: Sound) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension Sound {
    /// The complete set of ambient tracks shipped with Hush.
    ///
    /// Bundle files live under `Resources/Audio` as AAC ``.m4a`` (recommended: **128 kbps AAC,
    /// 44.1 kHz stereo**). For seamless looping, export with matching zero-crossings or
    /// verified loop points; silent placeholders may be any short length.
    static let library: [Sound] = [
        Sound(
            id: "rain_window",
            name: "sound.rain_window",
            category: .nature,
            resourceName: "rain_window",
            symbolName: "cloud.rain.fill"
        ),
        Sound(
            id: "thunderstorm_distant",
            name: "sound.thunderstorm_distant",
            category: .nature,
            resourceName: "thunderstorm",
            symbolName: "cloud.bolt.fill"
        ),
        Sound(
            id: "forest_birds_wind",
            name: "sound.forest_birds_wind",
            category: .nature,
            resourceName: "forest",
            symbolName: "leaf.fill"
        ),
        Sound(
            id: "ocean_waves",
            name: "sound.ocean_waves",
            category: .nature,
            resourceName: "ocean_waves",
            symbolName: "water.waves"
        ),
        
        Sound(
            id: "coffee_shop_chatter",
            name: "sound.coffee_shop_chatter",
            category: .cafeUrban,
            resourceName: "coffee_shop",
            symbolName: "cup.and.saucer.fill"
        ),
        Sound(
            id: "cafe",
            name: "sound.cafe",
            category: .cafeUrban,
            resourceName: "cafe",
            symbolName: "mug.fill"
        ),
        Sound(
            id: "city_traffic",
            name: "sound.city_traffic",
            category: .cafeUrban,
            resourceName: "city_traffic",
            symbolName: "car.fill"
        ),
        Sound(
            id: "train_ride",
            name: "sound.train_ride",
            category: .cafeUrban,
            resourceName: "train_ride",
            symbolName: "train.side.front.car"
        ),
        Sound(
            id: "tram_ride",
            name: "sound.tram_ride",
            category: .cafeUrban,
            resourceName: "tram_ride",
            symbolName: "tram.fill"
        ),
        Sound(
            id: "city_rain",
            name: "sound.city_rain",
            category: .cafeUrban,
            resourceName: "city_rain",
            symbolName: "building.2.crop.circle.fill"
        ),

        Sound(
            id: "buiding_noize",
            name: "sound.buiding_noize",
            category: .focusAbstract,
            resourceName: "buiding_noize",
            symbolName: "building.2.fill"
        ),
        Sound(
            id: "pink_noise",
            name: "sound.pink_noise",
            category: .focusAbstract,
            resourceName: "pink_noise",
            symbolName: "waveform.circle"
        ),
        Sound(
            id: "fan_white_noise",
            name: "sound.fan_white_noise",
            category: .focusAbstract,
            resourceName: "fan_noise",
            symbolName: "fanblades.fill"
        ),
        Sound(
            id: "fireplace_crackle",
            name: "sound.fireplace_crackle",
            category: .focusAbstract,
            resourceName: "fireplace",
            symbolName: "flame.fill"
        ),
    ]
}
