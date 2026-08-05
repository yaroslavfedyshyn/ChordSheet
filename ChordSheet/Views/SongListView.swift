import SwiftUI
import UniformTypeIdentifiers

/// A song to open in the editor (existing or a freshly-created blank draft).
struct SongRoute: Hashable {
    let song: Song
}

// Pin/unpin and unpin-all mutate `store.songs` inside a transaction with
// `disablesAnimations = true`: `List` runs its own implicit animation for
// row moves regardless of whether the surrounding SwiftUI code animates
// anything, and that animation cross-fades/misorders rows on reorder. This
// suppresses it. Shared by `SongListView` and `SideMenu` (unpin-all lives
// in the latter).
private func mutatingList(_ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, body)
}

/// The song library: search, swipe-to-delete rows, a floating add button,
/// and a library menu (Import/Export a full backup file via the system
/// Files picker, plus a real accent color picker).
struct SongListView: View {
    @EnvironmentObject var store: SongStore
    @EnvironmentObject private var accentPreference: AccentPreference
    @EnvironmentObject private var languagePreference: LanguagePreference
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var menuOpen = false
    @State private var path = NavigationPath()
    @State private var pendingDelete: Song?
    @State private var activeTagFilters: Set<String> = []

    // MARK: - Backup (import/export)
    @State private var exportDocument = JSONFileDocument(data: Data())
    @State private var exportFilename = "ChordSheet-Backup"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImportBackup: LibraryBackup?
    @State private var backupErrorMessage: String?

    private let menuAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)

    /// How many songs currently wear each tag.
    private var tagCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for song in store.songs {
            for tag in song.tags { counts[tag, default: 0] += 1 }
        }
        return counts
    }

    /// `store.allTags` only ever contains tags attached to at least one
    /// song, so every entry here has a count of at least 1 by construction.
    private var filterChips: [(tag: String, count: Int)] {
        store.allTags.map { ($0, tagCounts[$0] ?? 0) }
    }

    /// Pinned songs first, unpinned after — a stable sort so within each
    /// group songs are ordered by the chosen sort order rather than jumping
    /// around every time this is recomputed.
    private var filteredSongs: [Song] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = store.songs.filter { song in
            if !activeTagFilters.isEmpty, !activeTagFilters.contains(where: { song.tags.contains($0) }) {
                return false
            }
            guard !q.isEmpty else { return true }
            return (song.title + " " + song.tags.joined(separator: " ")).lowercased().contains(q)
        }
        return sorted(matching, by: store.sortOrder).sorted { $0.pinned && !$1.pinned }
    }

    /// The exact visible order of songs, encoded as a single value — used to
    /// force the List to remount instead of animate when order changes. See
    /// the `.id(rowOrderKey)` call site in `listArea` for why.
    private var rowOrderKey: String {
        filteredSongs.map(\.id).joined(separator: "|")
    }

    private func sorted(_ songs: [Song], by order: SongSortOrder) -> [Song] {
        switch order {
        case .alphabetical:
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .mostRecent:
            return songs.sorted { $0.dateAdded > $1.dateAdded }
        case .oldestFirst:
            return songs.sorted { $0.dateAdded < $1.dateAdded }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    topBar
                    VStack(spacing: 0) {
                        if !filterChips.isEmpty {
                            tagFilterRow
                        }
                        listArea
                    }
                    .simultaneousGesture(TapGesture().onEnded { searchFocused = false })
                }

                addButton
            }
            .background(Theme.background.ignoresSafeArea())
            .overlay {
                SideMenu(
                    isOpen: menuOpen,
                    onClose: { withAnimation(menuAnimation) { menuOpen = false } },
                    onImport: { showImporter = true },
                    onExport: presentExporter
                )
            }
            .overlay {
                // A plain SwiftUI sheet, not `.alert()`: a system alert is a
                // `UIAlertController` under the hood — a separate UIKit
                // subsystem whose own presentation/dismissal isn't governed
                // by SwiftUI's `Transaction`/`withAnimation` at all, no
                // matter how the state change that triggers it is wrapped.
                // That's why deferring the mutation, disabling animations
                // around it, etc. never touched the jump: none of that can
                // reach a UIAlertController's dismissal. A view built from
                // ordinary SwiftUI buttons is fully within our control.
                if let song = pendingDelete {
                    DeleteConfirmSheet(
                        songTitle: song.title,
                        onCancel: { pendingDelete = nil },
                        onDelete: {
                            pendingDelete = nil
                            mutatingList { store.delete(id: song.id) }
                        }
                    )
                }
            }
            .animation(.easeOut(duration: 0.18), value: pendingDelete != nil)
            .navigationBarHidden(true)
            .navigationDestination(for: SongRoute.self) { route in
                SongDetailView(song: route.song, store: store, language: languagePreference.language)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { _ in }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImportPick(result)
            }
            .alert(
                languagePreference.t[.replaceLibraryTitle],
                isPresented: Binding(get: { pendingImportBackup != nil }, set: { if !$0 { pendingImportBackup = nil } })
            ) {
                Button(languagePreference.t[.cancel], role: .cancel) { pendingImportBackup = nil }
                Button(languagePreference.t[.replaceButton], role: .destructive) {
                    if let backup = pendingImportBackup { store.replaceLibrary(with: backup) }
                    pendingImportBackup = nil
                }
            } message: {
                if let backup = pendingImportBackup {
                    Text(languagePreference.t.importingWillReplace(currentCount: store.songs.count, importedCount: backup.songs.count))
                }
            }
            .alert(
                languagePreference.t[.importFailedTitle],
                isPresented: Binding(get: { backupErrorMessage != nil }, set: { if !$0 { backupErrorMessage = nil } })
            ) {
                Button(languagePreference.t[.ok], role: .cancel) { backupErrorMessage = nil }
            } message: {
                Text(backupErrorMessage ?? "")
            }
        }
    }

    // MARK: - Backup (import/export)

    private func presentExporter() {
        let backup = store.makeBackup()
        guard let data = try? backup.encoded() else {
            backupErrorMessage = languagePreference.t[.couldntPrepareExport]
            return
        }
        exportDocument = JSONFileDocument(data: data)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        exportFilename = "ChordSheet-Backup-\(formatter.string(from: Date()))"
        showExporter = true
    }

    private func handleImportPick(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            backupErrorMessage = languagePreference.t[.couldntOpenFile]
        case .success(let url):
            do {
                let data = try readSecurityScoped(url: url)
                pendingImportBackup = try LibraryBackup.decode(from: data)
            } catch let error as LibraryBackup.ImportError {
                switch error {
                case .corrupt:
                    backupErrorMessage = languagePreference.t[.backupCorrupt]
                case .unsupportedSchemaVersion:
                    backupErrorMessage = languagePreference.t[.backupUnsupportedVersion]
                }
            } catch {
                backupErrorMessage = languagePreference.t[.couldntReadFile]
            }
        }
    }

    private func readSecurityScoped(url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

    // MARK: - Top bar (search + menu, same row)

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
                TextField(languagePreference.t[.search], text: $query)
                    .font(AppFont.sans(16))
                    .foregroundColor(Theme.ink)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .focused($searchFocused)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("clearSearchButton")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.searchField))

            Button {
                withAnimation(menuAnimation) { menuOpen = true }
            } label: {
                VStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.ink)
                            .frame(width: 19, height: 1.5)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("libraryMenuButton")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - Tag filter row

    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Button {
                    activeTagFilters.removeAll()
                } label: {
                    Text(languagePreference.t[.all])
                        .font(AppFont.sans(14, weight: .semibold))
                        .foregroundColor(activeTagFilters.isEmpty ? .white : Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(activeTagFilters.isEmpty ? Theme.accent : Theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tagFilterAll")

                ForEach(filterChips, id: \.tag) { chip in
                    let on = activeTagFilters.contains(chip.tag)
                    Button {
                        if on { activeTagFilters.remove(chip.tag) } else { activeTagFilters.insert(chip.tag) }
                    } label: {
                        HStack(spacing: 7) {
                            Text(chip.tag)
                                .font(AppFont.sans(14, weight: .medium))
                                .foregroundColor(on ? .white : Theme.ink)
                            Text("\(chip.count)")
                                .font(AppFont.mono(11, weight: .bold))
                                .foregroundColor(on ? Color.white.opacity(0.7) : Theme.muted)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .background(on ? Theme.accent : Theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tagFilter_\(chip.tag)")
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 13)
    }

    // MARK: - List

    private var listArea: some View {
        Group {
            if filteredSongs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredSongs) { song in
                        row(for: song)
                    }
                    Color.clear
                        .frame(height: 120)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .scrollDismissesKeyboard(.immediately)
                // Forces a full teardown/remount of the List whenever the
                // visible order changes, instead of asking SwiftUI to diff
                // old vs. new and animate the difference — `List`'s own
                // move/delete animation misbehaves (cross-fading rows into
                // each other, rows rendering behind their neighbors) no
                // matter how the mutation triggering it is wrapped. With no
                // old view to diff against, there's nothing to animate: the
                // list just reappears in its new order. Costs the scroll
                // position on every reorder (snaps back to top), which
                // reads fine here since pinning is exactly the action that
                // means "I want this at the top."
                .id(rowOrderKey)
                .transaction { $0.disablesAnimations = true }
            }
        }
    }

    private func row(for song: Song) -> some View {
        // Plain content + `.onTapGesture`, not a `Button`: when a List row's
        // content is itself a Button, `swipeActions` suppresses/hides that
        // control's rendering for as long as the actions are revealed (to
        // keep the swipe gesture from also triggering the button) — which
        // blanked the entire row (title, key, tags) the moment you swiped,
        // and made the pin animation look like it was reordering an empty
        // row. A non-interactive container has nothing for swipeActions to
        // suppress, so content stays visible throughout.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if song.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                }
                Text(song.title)
                    .font(AppFont.sans(17, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: 6) {
                Text(song.key)
                    .font(AppFont.mono(13, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Theme.accent.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                if song.tags.isEmpty {
                    Text(languagePreference.t[.noTags])
                        .font(AppFont.sans(13.5))
                        .foregroundColor(Theme.muted.opacity(0.75))
                } else {
                    ForEach(song.tags, id: \.self) { tag in
                        Text(tag)
                            .font(AppFont.sans(13, weight: .medium))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 9)
                            .frame(height: 23)
                            .background(Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            // A hairline border so the chip still reads as
                            // its own shape on a pinned row's tinted
                            // background, which is close enough to
                            // `surface2` that the fill alone isn't enough.
                            // Unpinned rows don't need it.
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(song.pinned ? Theme.divider : .clear, lineWidth: 1.5)
                            )
                    }
                }
            }
            .clipped()
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A faint wash of `ink` (not `surface2`, which the row's own tag/key
        // chips already sit on — reusing it here would flatten them into the
        // background) over the base background. Since `ink` itself is
        // near-black in light mode and near-white in dark mode, this settles
        // into a *subtle darkening* in light mode and a *subtle lightening*
        // in dark mode — the correct direction for "slightly grayed" in each
        // theme, not just one hardcoded gray that only reads right in light.
        //
        // Painted here (inside the row's own identity-tracked content)
        // rather than via `.listRowBackground`, which renders on a separate
        // layer that `List` composites by row *slot* rather than by the
        // row's `id` — tying the fill to this view instead keeps it glued
        // to the correct song regardless of how `List` reorders things.
        .background(song.pinned ? Theme.ink.opacity(0.05) : Theme.background)
        .contentShape(Rectangle())
        .onTapGesture {
            searchFocused = false
            path.append(SongRoute(song: song))
        }
        .accessibilityIdentifier("songRow_\(song.id)")
        .listRowInsets(EdgeInsets())
        .listRowSeparatorTint(Theme.divider)
        .listRowBackground(Color.clear)
        // `allowsFullSwipe: false`: with it true, dragging all the way
        // triggers the destructive button immediately and iOS starts
        // animating the row collapsing away, assuming a deletion is
        // actually happening. Our handler only asks for confirmation —
        // nothing backs that collapse animation up, so it snaps back,
        // which read as the rows below jumping down then bouncing back.
        // Requiring an explicit tap on the button (never an auto-triggered
        // full swipe) means nothing about the row animates until the user
        // actually confirms.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = song
            } label: {
                Label(languagePreference.t[.delete], systemImage: "trash")
            }
            .tint(.red)
            .labelStyle(.iconOnly)

            Button {
                mutatingList { store.togglePin(id: song.id) }
            } label: {
                Label(song.pinned ? languagePreference.t[.unpin] : languagePreference.t[.pin], systemImage: song.pinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(Theme.accent)
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("pinButton_\(song.id)")
        }
    }

    private var emptyState: some View {
        VStack {
            Text(emptyLine)
                .font(AppFont.sans(15.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .padding(.top, 120)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var emptyLine: String {
        let t = languagePreference.t
        if store.songs.isEmpty { return t[.emptyNone] }
        if !activeTagFilters.isEmpty {
            return t.format(.emptyTag, activeTagFilters.sorted().joined(separator: " \(t[.or]) "))
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.format(.emptyQuery, trimmed)
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            searchFocused = false
            let newSong = Song(id: SongStore.newSongID(), title: "", artist: "", key: "C", body: "")
            path.append(SongRoute(song: newSong))
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 62, height: 62)
                .background(Theme.accent)
                .clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.34), radius: 22, x: 0, y: 8)
                .shadow(color: .black.opacity(0.14), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addSongButton")
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

/// "Delete this song?" guard, shown before a swipe-to-delete actually
/// removes anything. A plain SwiftUI sheet rather than `.alert()` — see the
/// comment at its call site in `SongListView.body` for why.
private struct DeleteConfirmSheet: View {
    @EnvironmentObject private var languagePreference: LanguagePreference
    let songTitle: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(languagePreference.t.format(.deleteConfirmTitle, languagePreference.t.songRef(title: songTitle)))
                        .font(AppFont.sans(16.5, weight: .semibold))
                        .foregroundColor(Theme.ink)
                    Text(languagePreference.t[.cantUndo])
                        .font(AppFont.sans(14))
                        .foregroundColor(Theme.muted)
                }

                VStack(spacing: 9) {
                    Button(action: onDelete) {
                        Text(languagePreference.t[.delete])
                            .font(AppFont.sans(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("confirmDeleteButton")

                    Button(action: onCancel) {
                        Text(languagePreference.t[.cancel])
                            .font(AppFont.sans(16, weight: .medium))
                            .foregroundColor(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cancelDeleteButton")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 46)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .clipShape(RoundedCorner(radius: 22, corners: [.topLeft, .topRight]))
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }
}

/// The right-side "LIBRARY" drawer with Import/Export (full-library backup
/// file, via the system Files picker) plus an "APPEARANCE" block: the
/// Light/Dark/Auto control together with the 4 accent-color swatches from
/// the design's own `accent` prop, grouped under one heading since both are
/// appearance settings.
private struct SideMenu: View {
    @EnvironmentObject private var store: SongStore
    @EnvironmentObject private var accentPreference: AccentPreference
    @EnvironmentObject private var appearancePreference: AppearancePreference
    @EnvironmentObject private var languagePreference: LanguagePreference
    let isOpen: Bool
    let onClose: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        // Each piece needs its own `if isOpen` (not one shared at the call
        // site) so SwiftUI knows to insert/remove *this specific subtree*
        // on toggle and actually run its `.transition` — a `.transition`
        // applied to a child that's always present, inside a parent that's
        // conditionally mounted from outside, is inert: SwiftUI decides the
        // parent's own mount/unmount using the default (fade), regardless
        // of what transitions its children declare.
        ZStack(alignment: .trailing) {
            if isOpen {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .transition(.opacity)
            }

            if isOpen {
                panel
                    .transition(.move(edge: .trailing))
            }
        }
    }

    private var panel: some View {
        let t = languagePreference.t
        return VStack(alignment: .leading, spacing: 0) {
            if store.hasPinnedSongs {
                menuRow(icon: "pin.slash", title: t[.unpinAll], bottomDivider: true) {
                    mutatingList { store.unpinAll() }
                }
                .accessibilityIdentifier("unpinAllRow")
            }

            Text(t[.library])
                .font(AppFont.mono(10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 22)
                .padding(.top, store.hasPinnedSongs ? 22 : 0)
                .padding(.bottom, 18)

            menuRow(icon: "square.and.arrow.down", title: t[.importSongs], topDivider: true) {
                onClose()
                onImport()
            }
            .accessibilityIdentifier("importSongsRow")
            menuRow(icon: "square.and.arrow.up", title: t[.exportSongs], topDivider: true, bottomDivider: true) {
                onClose()
                onExport()
            }
            .accessibilityIdentifier("exportSongsRow")

            Text(t[.sortHeader])
                .font(AppFont.mono(10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 12)

            Menu {
                ForEach(SongSortOrder.allCases) { order in
                    Button {
                        store.sortOrder = order
                    } label: {
                        if store.sortOrder == order {
                            Label(t.label(for: order), systemImage: "checkmark")
                        } else {
                            Text(t.label(for: order))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(t.label(for: store.sortOrder))
                        .font(AppFont.sans(15, weight: .medium))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 22)
            .accessibilityIdentifier("sortMenuButton")

            Text(t[.appearance])
                .font(AppFont.mono(10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 12)

            HStack(spacing: 3) {
                ForEach(AppearanceMode.allCases) { mode in
                    AppearanceSegment(mode: mode, isSelected: appearancePreference.mode == mode) {
                        appearancePreference.mode = mode
                    }
                }
            }
            .padding(3)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 22)
            .padding(.bottom, 16)

            HStack(spacing: 0) {
                ForEach(AccentTheme.allCases) { theme in
                    ThemeSwatch(theme: theme, isSelected: accentPreference.theme == theme) {
                        accentPreference.theme = theme
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 22)

            Text(t[.language])
                .font(AppFont.mono(10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 12)

            Menu {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        languagePreference.language = lang
                    } label: {
                        if languagePreference.language == lang {
                            Label(lang.nativeName, systemImage: "checkmark")
                        } else {
                            Text(lang.nativeName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(languagePreference.language.nativeName)
                        .font(AppFont.sans(15, weight: .medium))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 22)
            .accessibilityIdentifier("languageMenuButton")

            if let deviceNote = LanguagePreference.deviceNote(activeLanguage: languagePreference.language) {
                Text(deviceNote)
                    .font(AppFont.sans(12))
                    .foregroundColor(Theme.muted)
                    .lineLimit(3)
                    .padding(.horizontal, 22)
                    .padding(.top, 13)
            }

            Spacer()
        }
        .padding(.top, 74)
        .frame(width: 272, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(Theme.surface)
        .ignoresSafeArea(edges: .vertical)
        .shadow(color: .black.opacity(0.2), radius: 40, x: -14, y: 0)
    }

    private func menuRow(icon: String, title: String, topDivider: Bool = false, bottomDivider: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(AppFont.sans(16.5, weight: .medium))
                    .foregroundColor(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { if topDivider { Rectangle().fill(Theme.divider).frame(height: 1) } }
        .overlay(alignment: .bottom) { if bottomDivider { Rectangle().fill(Theme.divider).frame(height: 1) } }
    }
}

/// One segment of the Light/Dark/Auto appearance control.
private struct AppearanceSegment: View {
    @EnvironmentObject private var languagePreference: LanguagePreference
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(languagePreference.t.label(for: mode))
                .font(AppFont.sans(14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Theme.ink : Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? Theme.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: isSelected ? Color.black.opacity(0.14) : .clear, radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("appearanceMode_\(mode.rawValue)")
    }
}

/// One swatch in the accent-color picker: the letter "C" in that theme's
/// color, with a tinted background + ring when it's the current selection.
private struct ThemeSwatch: View {
    @EnvironmentObject private var languagePreference: LanguagePreference
    let theme: AccentTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("C")
                    .font(AppFont.mono(18, weight: .bold))
                    .foregroundColor(theme.color)
                    .frame(width: 46, height: 46)
                    .background(isSelected ? theme.color.opacity(0.14) : Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(isSelected ? theme.color : .clear, lineWidth: 2)
                    )
                Text(languagePreference.t.label(for: theme))
                    .font(AppFont.mono(8.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundColor(Theme.muted)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("themeSwatch_\(theme.rawValue)")
    }
}

/// Minimal `FileDocument` wrapper so `.fileExporter` can hand pre-encoded
/// JSON `Data` to the system save picker without a dedicated document type.
private struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
