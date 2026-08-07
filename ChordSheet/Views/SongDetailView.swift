import SwiftUI
import UIKit

/// The song editor screen: inline title, font-size stepper, key badge /
/// transpose strip, the chord-highlighted canvas, and the chord bar.
struct SongDetailView: View {
    @StateObject private var vm: SongEditorViewModel
    @EnvironmentObject private var accentPreference: AccentPreference
    @EnvironmentObject private var languagePreference: LanguagePreference
    @Environment(\.dismiss) private var dismiss

    init(song: Song, store: SongStore, language: AppLanguage) {
        _vm = StateObject(wrappedValue: SongEditorViewModel(song: song, store: store, language: language))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tagsRow

            if vm.stripOpen {
                TransposeStripView(vm: vm)
            }

            canvasArea

            if vm.isEditing {
                ChordBarView(vm: vm)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .background(SwipeBackDisabler())
        .onAppear { vm.focusCanvasIfNewSong() }
        // Keep the screen awake while a song is open — useful for reading
        // chords hands-free during a performance — and restore normal
        // auto-lock as soon as the editor closes.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView()
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.22), value: vm.showToast)
            }
        }
        .overlay {
            if vm.confirmOpen {
                ConfirmSheet(
                    songTitle: vm.draft.title,
                    onStay: vm.stay,
                    onSave: { vm.saveAndBack { dismiss() } },
                    onDiscard: { vm.discardAndBack { dismiss() } }
                )
            }
        }
        .overlay {
            if vm.tagSheetOpen {
                TagSheetView(vm: vm)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: vm.stripOpen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: vm.isEditing)
        .animation(.easeOut(duration: 0.18), value: vm.confirmOpen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: vm.tagSheetOpen)
    }

    private var tagsRow: some View {
        Button(action: vm.openTags) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(vm.draft.tags, id: \.self) { tag in
                        Text(tag)
                            .font(AppFont.sans(13.5, weight: .medium))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 30)
                            .background(Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text(vm.draft.tags.isEmpty ? languagePreference.t[.addTags] : languagePreference.t[.tagOne])
                            .font(AppFont.sans(13.5, weight: .medium))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 13)
                    .frame(height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1.3)
                    )
                }
                .padding(.leading, 16)
                .padding(.trailing, 20)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("openTagsButton")
        .frame(height: 46)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .bottom)
    }

    private func back() {
        if vm.requestBack() {
            dismiss()
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backButton")

            TextField(languagePreference.t[.untitled], text: Binding(
                get: { vm.draft.title },
                set: { vm.setTitle($0) }
            ))
            .accessibilityIdentifier("titleField")
            .font(AppFont.sans(16.5, weight: .semibold))
            .foregroundColor(Theme.ink)
            .submitLabel(.done)
            .layoutPriority(-1)

            Button(action: vm.smaller) {
                Text("A\u{2212}")
                    .font(AppFont.mono(13, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fontSmaller")

            Button(action: vm.bigger) {
                Text("A+")
                    .font(AppFont.mono(17, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 40, height: 44)
            }
            .accessibilityIdentifier("fontBigger")
            .buttonStyle(.plain)

            Button(action: vm.toggleStrip) {
                Text(vm.draft.key)
                    .font(AppFont.mono(14.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 36)
                    .frame(height: 30)
                    .padding(.horizontal, 9)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Theme.accent.opacity(vm.stripOpen ? 0.25 : 0), lineWidth: 3)
                            .padding(-3)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("keyBadge")
            .frame(minWidth: 46)
            .frame(height: 44)

            if vm.dirty {
                Button(action: vm.save) {
                    Text(languagePreference.t[.save])
                        .font(AppFont.sans(15.5, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, 10)
                        .padding(.trailing, 6)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saveButton")
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .frame(height: 52)
    }

    private var canvasArea: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    if vm.draft.body.isEmpty {
                        Text(languagePreference.t[.startHint])
                            .font(AppFont.sans(15.5))
                            .foregroundColor(Theme.muted)
                            .allowsHitTesting(false)
                            .frame(width: max(geo.size.width - 40, 0), alignment: .leading)
                    }
                    ChordCanvasView(
                        text: Binding(get: { vm.draft.body }, set: { vm.setBody($0) }),
                        cursor: Binding(get: { vm.cursor }, set: { vm.setCursor($0) }),
                        fontSize: vm.fontSize,
                        accentTheme: accentPreference.theme,
                        focusToken: vm.focusToken,
                        blurToken: vm.blurToken,
                        onBeginEditing: vm.onCanvasFocus,
                        onEndEditing: vm.onCanvasBlur
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 10)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
            }
            .contentShape(Rectangle())
            .accessibilityIdentifier("canvasArea")
            .onTapGesture {
                if !vm.isEditing { vm.focusCanvas() }
            }
        }
    }
}

/// Forces navigation back through the custom back button (which runs the
/// unsaved-changes guard) by disabling the interactive edge-swipe-to-pop
/// gesture while this screen is visible.
private struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        DisablerViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class DisablerViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
