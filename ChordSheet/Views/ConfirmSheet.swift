import SwiftUI

/// "Keep your changes?" guard shown when leaving a song with unsaved edits.
struct ConfirmSheet: View {
    @EnvironmentObject private var accentPreference: AccentPreference
    @EnvironmentObject private var languagePreference: LanguagePreference
    let songTitle: String
    let onStay: () -> Void
    let onSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onStay)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(languagePreference.t[.keepChanges])
                        .font(AppFont.sans(16.5, weight: .semibold))
                        .foregroundColor(Theme.ink)
                    Text(languagePreference.t.format(.unsaved, languagePreference.t.songRef(title: songTitle)))
                        .font(AppFont.sans(14))
                        .foregroundColor(Theme.muted)
                }

                VStack(spacing: 9) {
                    Button(action: onSave) {
                        Text(languagePreference.t[.save])
                            .font(AppFont.sans(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("confirmSaveButton")

                    Button(action: onDiscard) {
                        Text(languagePreference.t[.discard])
                            .font(AppFont.sans(16, weight: .medium))
                            .foregroundColor(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("confirmDiscardButton")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 46)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .clipShape(RoundedCorner(radius: 22, corners: [.topLeft, .topRight]))
        }
        // On the whole container, not just the card — a child's own
        // ignoresSafeArea doesn't move where `.bottom` alignment anchors it
        // within a parent that's still safe-area-constrained.
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }
}
