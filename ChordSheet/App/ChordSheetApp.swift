import SwiftUI

@main
struct ChordSheetApp: App {
    @StateObject private var store = SongStore()
    @StateObject private var accentPreference = AccentPreference.shared
    @StateObject private var appearancePreference = AppearancePreference.shared
    @StateObject private var languagePreference = LanguagePreference.shared

    var body: some Scene {
        WindowGroup {
            SongListView()
                .environmentObject(store)
                .environmentObject(accentPreference)
                .environmentObject(appearancePreference)
                .environmentObject(languagePreference)
                .tint(accentPreference.theme.color)
                .preferredColorScheme(appearancePreference.mode.colorScheme)
        }
    }
}
