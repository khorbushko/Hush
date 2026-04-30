import Foundation

/// A saved combination of active sounds and their volumes.
public struct SoundPreset: Codable, Identifiable, Sendable {
    public var id: UUID
    /// Normalised volumes keyed by `Sound.id` — only enabled sounds are stored.
    public var tracks: [String: Double]
    /// SF symbol names of the saved sounds, ordered as in `Sound.library`.
    public var symbolNames: [String]
    /// Hue (0 … 1) used to derive the card's soft background colour.
    public var hue: Double
    public var createdAt: Date

    public init(tracks: [String: Double], symbolNames: [String], hue: Double) {
        self.id = UUID()
        self.tracks = tracks
        self.symbolNames = symbolNames
        self.hue = hue
        self.createdAt = Date()
    }
}
