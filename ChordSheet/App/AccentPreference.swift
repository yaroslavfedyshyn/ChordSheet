import SwiftUI

/// The 4 accent presets from the design's `accent` prop (a `Look`-section
/// color picker: `["#2A8C82","#2F6DB5","#B0552E","#5A4FB0"]`).
enum AccentTheme: String, CaseIterable, Identifiable {
    case teal, marine, clay, plum

    var id: String { rawValue }

    private var lightHex: (UInt8, UInt8, UInt8) {
        switch self {
        case .teal: return (0x2A, 0x8C, 0x82)
        case .marine: return (0x2F, 0x6D, 0xB5)
        case .clay: return (0xB0, 0x55, 0x2E)
        case .plum: return (0x5A, 0x4F, 0xB0)
        }
    }

    /// Only the default teal gets a dedicated dark-mode swap in the design
    /// (`(theme==='dark' && acc==='#2A8C82') ? '#34A99C' : acc`) — every
    /// other accent choice passes through unchanged in dark mode too.
    private var darkHex: (UInt8, UInt8, UInt8) {
        switch self {
        case .teal: return (0x34, 0xA9, 0x9C)
        default: return lightHex
        }
    }

    var uiColor: UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? self.darkHex : self.lightHex
            return UIColor(red: CGFloat(hex.0) / 255, green: CGFloat(hex.1) / 255, blue: CGFloat(hex.2) / 255, alpha: 1)
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

/// The user's chosen accent color, persisted across launches.
final class AccentPreference: ObservableObject {
    static let shared = AccentPreference()

    @Published var theme: AccentTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.key) }
    }

    private static let key = "accentTheme"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key), let saved = AccentTheme(rawValue: raw) {
            theme = saved
        } else {
            theme = .teal
        }
    }
}
