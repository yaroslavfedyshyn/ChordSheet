import SwiftUI
import UIKit

/// Color tokens ported from the design's CSS custom properties
/// (`--bg`, `--ink`, `--mut`, `--acc`, `--div`, `--surf`, `--surf2`).
/// Each maps to a color set in Assets.xcassets with light/dark variants,
/// so views automatically follow the system appearance.
enum Theme {
    static let background = Color("AppBackground")
    static let ink = Color("Ink")
    static let muted = Color("Muted")
    /// The user's chosen accent color (see `AccentPreference`) — defaults to
    /// the design's teal. Reads the live preference so it always reflects
    /// the current selection once a view holding `AccentPreference` re-renders.
    static var accent: Color { AccentPreference.shared.theme.color }
    static let divider = Color("Divider")
    static let surface = Color("Surface")
    static let surface2 = Color("Surface2")

    enum Radius {
        static let searchField: CGFloat = 13
        static let transposePill: CGFloat = 13
        static let chordChip: CGFloat = 11
        static let sheet: CGFloat = 22
        static let fab: CGFloat = 31
    }
}

/// Font families ported from the design's Google Fonts import
/// (`JetBrains Mono` for chords/mono UI, `IBM Plex Sans` for body text).
enum AppFont {
    // JetBrains Mono
    static func mono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        Font.custom(weight.jetBrainsName, size: size)
    }

    // IBM Plex Sans
    static func sans(_ size: CGFloat, weight: Weight = .regular) -> Font {
        Font.custom(weight.plexName, size: size)
    }

    static func monoUIFont(_ size: CGFloat, weight: Weight = .regular) -> UIFont {
        UIFont(name: weight.jetBrainsName, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight.uiWeight)
    }

    enum Weight {
        case regular, medium, semibold, bold

        var jetBrainsName: String {
            switch self {
            case .regular: return "JetBrainsMono-Regular"
            case .medium: return "JetBrainsMono-Medium"
            case .semibold: return "JetBrainsMono-Medium"
            case .bold: return "JetBrainsMono-Bold"
            }
        }

        var plexName: String {
            switch self {
            case .regular: return "IBMPlexSans"
            case .medium: return "IBMPlexSans-Medm"
            case .semibold: return "IBMPlexSans-SmBld"
            case .bold: return "IBMPlexSans-SmBld"
            }
        }

        var uiWeight: UIFont.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }
}
