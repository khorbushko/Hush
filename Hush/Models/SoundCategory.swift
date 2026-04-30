import Foundation

/// Logical grouping for bundled ambient tracks in the Hush library.
public enum SoundCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Natural outdoor and weather atmospheres.
    case nature
    /// Café chatter, transit, and street ambience.
    case cafeUrban = "cafe_urban"
    /// Noise colors and abstract masking layers.
    case focusAbstract = "focus_abstract"

    /// Mirrors the raw persistence key for identifiable sections.
    public var id: String { rawValue }

    /// User-facing section title for the category.
    public var displayName: String {
        switch self {
        case .nature: "Nature"
        case .cafeUrban: "Café & Urban"
        case .focusAbstract: "Focus & Abstract"
        }
    }
}
