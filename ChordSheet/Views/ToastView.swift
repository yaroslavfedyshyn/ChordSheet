import SwiftUI

/// The transient "Saved" confirmation shown after a successful save.
struct ToastView: View {
    @EnvironmentObject private var languagePreference: LanguagePreference

    var body: some View {
        Text(languagePreference.t[.saved])
            .font(AppFont.sans(14, weight: .medium))
            .foregroundColor(Theme.background)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Theme.ink)
            .clipShape(Capsule())
            .allowsHitTesting(false)
    }
}
