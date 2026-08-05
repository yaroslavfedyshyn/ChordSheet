import SwiftUI

/// Bottom sheet for editing which tags apply to the current song: search or
/// create a tag, then tap chips on/off. Mirrors the design prototype's
/// `tagSheet` overlay.
struct TagSheetView: View {
    @ObservedObject var vm: SongEditorViewModel
    @EnvironmentObject private var languagePreference: LanguagePreference
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { vm.closeTags() }

            VStack(alignment: .leading, spacing: 0) {
                header
                searchField
                tagArea
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 620)
            .background(Theme.surface)
            .clipShape(RoundedCorner(radius: Theme.Radius.sheet, corners: [.topLeft, .topRight]))
        }
        // On the whole container, not just the card — a child's own
        // ignoresSafeArea doesn't move where `.bottom` alignment anchors it
        // within a parent that's still safe-area-constrained.
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }

    private var header: some View {
        HStack {
            Text(languagePreference.t[.tagsHeader])
                .font(AppFont.sans(16.5, weight: .semibold))
                .foregroundColor(Theme.ink)
            Spacer()
            Button(languagePreference.t[.done]) { vm.closeTags() }
                .buttonStyle(.plain)
                .font(AppFont.sans(15.5, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(height: 44)
                .accessibilityIdentifier("closeTagsButton")
        }
        .padding(.leading, 22)
        .padding(.trailing, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            TextField(languagePreference.t[.findTag], text: Binding(get: { vm.tagQuery }, set: { vm.tagQuery = $0 }))
                .focused($searchFocused)
                .font(AppFont.sans(16))
                .foregroundColor(Theme.ink)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { vm.createTag() }
                .accessibilityIdentifier("tagSearchField")

            if vm.canCreateTag {
                Button(languagePreference.t[.create]) { vm.createTag() }
                    .buttonStyle(.plain)
                    .font(AppFont.sans(14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .accessibilityIdentifier("createTagButton")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 46)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.searchField))
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var tagArea: some View {
        ScrollView {
            if vm.sheetTags.isEmpty {
                Text(vm.sheetEmptyLine)
                    .font(AppFont.sans(15))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 34)
            } else {
                FlowLayout(spacing: 9, lineSpacing: 9) {
                    ForEach(vm.sheetTags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let on = vm.draft.tags.contains(tag)
        // Background color alone signals selection — no checkmark, so a
        // chip's width (and the row it wraps into) never shifts on toggle.
        return Button { vm.toggleTag(tag) } label: {
            Text(tag)
                .font(AppFont.sans(15.5, weight: .medium))
                .foregroundColor(on ? .white : Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(on ? Theme.accent : Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tagChip_\(tag)")
    }
}
