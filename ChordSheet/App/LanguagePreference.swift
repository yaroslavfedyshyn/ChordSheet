import SwiftUI

/// The user's chosen app language, persisted across launches — an in-app
/// switcher independent of the device's own Settings > Language, matching
/// the design prototype's sidebar "LANGUAGE" section. On first launch
/// (nothing saved yet) it guesses from the device's preferred language,
/// falling back to English if that language isn't one of the 6 supported
/// (mirrors the design's `autoLang()`).
final class LanguagePreference: ObservableObject {
    static let shared = LanguagePreference()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }

    private static let key = "appLanguage"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key), let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = Self.systemLanguage()
        }
    }

    /// The device's preferred language, mapped to one of the 6 supported
    /// languages if possible — otherwise English.
    static func systemLanguage() -> AppLanguage {
        AppLanguage(rawValue: systemBaseCode()) ?? .en
    }

    private static func systemBaseCode() -> String {
        guard let tag = Locale.preferredLanguages.first else { return "en" }
        return String(tag.split(separator: "-").first ?? Substring(tag)).lowercased()
    }

    /// The sidebar's language-list footnote: tells the user what language
    /// their device is set to, and whether that language is supported here
    /// — `nil` once the device's own language is already the active one,
    /// since pointing that out would just be redundant. Mirrors the design's
    /// `deviceAsks`/`deviceMissing` + `sysName()` behavior: an unsupported
    /// device language is named using the *active* app language.
    static func deviceNote(activeLanguage: AppLanguage) -> String? {
        let base = systemBaseCode()
        let t = activeLanguage.strings
        if let known = AppLanguage(rawValue: base) {
            guard known != activeLanguage else { return nil }
            return t.format(.deviceAsks, known.nativeName)
        }
        let displayName = Locale(identifier: activeLanguage.rawValue).localizedString(forLanguageCode: base) ?? base
        return t.format(.deviceMissing, displayName)
    }
}

extension LanguagePreference {
    /// Convenience so call sites can write `languagePreference.t.search`
    /// instead of `L10n(language: languagePreference.language).search`.
    var t: L10n { language.strings }
}
