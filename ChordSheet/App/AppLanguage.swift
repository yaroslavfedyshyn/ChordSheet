import Foundation

/// The 6 languages the design prototype ships translations for
/// (`LANGS`/`T` in the design's `Component` class).
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case en, fr, de, es, ru, uk

    var id: String { rawValue }

    /// Each language's own name for itself, as listed in the sidebar's
    /// language picker (design's `LANGS[].native`).
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .ru: return "Русский"
        case .uk: return "Українська"
        }
    }
}
