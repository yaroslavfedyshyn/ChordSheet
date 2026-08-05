import SwiftUI

/// The app's Light/Dark/Auto setting from the design's sidebar "APPEARANCE"
/// section — independent of the system appearance (`Auto` is the only mode
/// that follows it).
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, auto

    var id: String { rawValue }

    /// `nil` for `.auto` lets SwiftUI's `.preferredColorScheme` fall through
    /// to the system setting instead of forcing one.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

/// The user's chosen appearance mode, persisted across launches.
final class AppearancePreference: ObservableObject {
    static let shared = AppearancePreference()

    @Published var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }

    private static let key = "appearanceMode"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key), let saved = AppearanceMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .auto
        }
    }
}
