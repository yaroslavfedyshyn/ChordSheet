import Foundation
import SwiftUI

enum ChordChipStyle {
    case active   // currently-selected variant, or the "NOW" transpose pill
    case outline  // other variant of the chord under the cursor
    case plain    // quick-insert chip
}

/// Result of a manual "Detect key" tap, shown in the panel under the button.
struct KeyDetectionResult {
    /// True when there weren't enough chords to make a guess.
    let none: Bool
    let name: String?
    let alternateName: String?
    let sameAsCurrent: Bool
}

/// Drives one song's editor screen: title/body editing, transpose, the
/// context-sensitive chord bar, and the unsaved-changes guard. Mirrors the
/// `screen === 'song'` state and methods of the design prototype's
/// `Component` class.
@MainActor
final class SongEditorViewModel: ObservableObject {
    @Published var draft: Song
    @Published var dirty: Bool
    @Published var cursor: Int = 0
    @Published var sizeIndex: Int = 2
    @Published var isEditing: Bool = false
    @Published var keyboardVisible: Bool = false
    @Published var stripOpen: Bool = false
    @Published var allOpen: Bool = false
    @Published var confirmOpen: Bool = false
    @Published var showToast: Bool = false
    @Published var tagSheetOpen: Bool = false
    @Published var tagQuery: String = ""
    @Published private(set) var keyDetection: KeyDetectionResult?
    @Published private(set) var focusToken: Int = 0
    @Published private(set) var blurToken: Int = 0

    let transposeRange: Int
    let accidentalsPreference: Accidentals

    private let store: SongStore
    /// The active UI language, captured once at init for this VM's own
    /// string-producing logic (the "Untitled song" fallback on save, the tag
    /// sheet's empty-state line). The language switcher lives in the list
    /// screen's sidebar, unreachable while a song is open, so it can't
    /// change mid-edit — views themselves still read the live
    /// `LanguagePreference` environment object for everything they render.
    private let strings: L10n
    private var toastTask: Task<Void, Never>?

    /// True only for a song that doesn't exist in the store yet. Gates
    /// automatic key detection: it's a convenience for songs being created
    /// from scratch, never a correction applied to something already saved.
    private let isNewSong: Bool
    /// Set once the user explicitly picks a key (via transpose), which
    /// permanently stops auto-detection from touching it for this session.
    private var keyManuallySet = false

    init(song: Song, store: SongStore, language: AppLanguage, transposeRange: Int = 11, accidentalsPreference: Accidentals = .auto) {
        self.draft = song
        self.dirty = false
        self.store = store
        self.strings = language.strings
        self.isNewSong = store.song(id: song.id) == nil
        // Capped at 11, not a full 12: +/-12 is the exact same pitch class
        // as the current key (a full octave), so that pill would be redundant.
        self.transposeRange = max(1, min(11, transposeRange))
        self.accidentalsPreference = accidentalsPreference
    }

    // MARK: - Title / body editing

    func setTitle(_ value: String) {
        draft.title = value
        dirty = true
    }

    func setBody(_ value: String) {
        draft.body = value
        dirty = true
        keyDetection = nil
        autoDetectKeyIfNeeded()
    }

    /// Keeps the key badge in sync with the best-guess key while a brand-new
    /// song is still being drafted, as long as the user hasn't picked a key
    /// themselves yet. Never touches a song that's already been saved.
    private func autoDetectKeyIfNeeded() {
        guard isNewSong, !keyManuallySet else { return }
        if let detected = ChordTheory.detectKey(from: draft.body) {
            draft.key = detected
        }
    }

    func setCursor(_ value: Int) {
        cursor = value
    }

    // MARK: - Focus / keyboard

    func onCanvasFocus() {
        isEditing = true
        keyboardVisible = true
        stripOpen = false
    }

    /// The chord bar only ever makes sense alongside a live keyboard to
    /// insert into, so losing focus always closes both together — reading
    /// an existing sheet should never be cluttered with editing chrome.
    func onCanvasBlur() {
        keyboardVisible = false
        isEditing = false
        allOpen = false
    }

    /// The chord bar's own "Hide keyboard" control — dismisses the real
    /// keyboard, which closes the chord bar with it via `onCanvasBlur()`
    /// once the resign completes. Equivalent to tapping away from the
    /// canvas, just reachable from within the bar itself.
    func hideKeyboard() {
        blurToken += 1
    }

    func focusCanvas() {
        isEditing = true
        focusToken += 1
    }

    /// Auto-focuses the canvas so a brand-new song opens with the keyboard
    /// already up — never for a song that's already been saved, since
    /// that would yank the keyboard open just for reading an existing sheet.
    func focusCanvasIfNewSong() {
        if isNewSong { focusCanvas() }
    }

    // MARK: - Font size

    func smaller() { sizeIndex = max(0, sizeIndex - 1) }
    func bigger() { sizeIndex = min(ChordTheory.fontSizes.count - 1, sizeIndex + 1) }
    var fontSize: CGFloat { ChordTheory.fontSizes[sizeIndex] }

    // MARK: - Transpose strip

    /// Whether the canvas was mid-edit (keyboard up) right before the strip
    /// opened, so closing it can seamlessly resume typing.
    private var resumeEditingAfterStripCloses = false

    func toggleStrip() {
        keyDetection = nil
        if stripOpen {
            stripOpen = false
            if resumeEditingAfterStripCloses {
                resumeEditingAfterStripCloses = false
                keyboardVisible = true
                focusCanvas()
            }
        } else {
            resumeEditingAfterStripCloses = isEditing
            stripOpen = true
            isEditing = false
            // Actually dismiss the real keyboard (not just hide the chord
            // bar) — otherwise it stays up behind the strip, and a tap on
            // an already-focused text view won't fire a new focus event to
            // bring the chord bar back later.
            if keyboardVisible {
                keyboardVisible = false
                blurToken += 1
            }
        }
    }

    var transposePills: [(semitones: Int, name: String, isCurrent: Bool)] {
        let key = ChordTheory.keyParts(draft.key)
        return (-transposeRange...transposeRange).map { i in
            (i, ChordTheory.keyName(pitchClass: key.pitchClass + i, minor: key.minor), i == 0)
        }
    }

    func transpose(semitones: Int) {
        stripOpen = false
        keyDetection = nil
        guard semitones != 0 else { return }
        keyManuallySet = true
        let key = ChordTheory.keyParts(draft.key)
        let newKey = ChordTheory.keyName(pitchClass: key.pitchClass + semitones, minor: key.minor)
        let flat = ChordTheory.flatPreferred(forKey: newKey, accidentals: accidentalsPreference)
        draft.key = newKey
        draft.body = ChordTheory.shiftBody(draft.body, semitones: semitones, flat: flat)
        dirty = true
    }

    /// Runs the manual key-detection algorithm against the current body and
    /// publishes the result for the panel under the "Detect key" button.
    func detectKey() {
        guard let guess = ChordTheory.detectKeyGuess(from: draft.body) else {
            keyDetection = KeyDetectionResult(none: true, name: nil, alternateName: nil, sameAsCurrent: false)
            return
        }
        keyDetection = KeyDetectionResult(
            none: false, name: guess.name, alternateName: guess.alternateName,
            sameAsCurrent: guess.name == draft.key
        )
    }

    /// Applies the detected key as the song's new key label. The chords
    /// already fit that key — only the stale badge/label changes, not a
    /// transposition of the sheet itself.
    func applyDetectedKey() {
        guard let name = keyDetection?.name else { return }
        keyManuallySet = true
        draft.key = name
        dirty = true
        keyDetection = nil
    }

    // MARK: - Tags

    /// Every tag worth showing in the sheet: every tag attached to some
    /// song, plus any this song's own draft already wears (so a tag just
    /// typed in for a brand-new song shows up immediately, even before
    /// saving is what actually makes it "real" for other songs).
    private var knownTags: [String] {
        let known = Set(store.allTags.map { $0.lowercased() })
        let extra = draft.tags.filter { !known.contains($0.lowercased()) }
        return store.allTags + extra
    }

    /// Known tags matching the current search text, always alphabetical —
    /// toggling a tag on/off must never reorder the list, only its
    /// highlighted state, so a tag stays where the user expects it.
    var sheetTags: [String] {
        let q = tagQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return knownTags
            .filter { q.isEmpty || $0.lowercased().contains(q) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var canCreateTag: Bool {
        let q = tagQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }
        return !knownTags.contains { $0.caseInsensitiveCompare(q) == .orderedSame }
    }

    var sheetEmptyLine: String {
        strings.format(.sheetEmpty, tagQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func openTags() {
        tagSheetOpen = true
        tagQuery = ""
        isEditing = false
    }

    func closeTags() {
        tagSheetOpen = false
        tagQuery = ""
    }

    func toggleTag(_ name: String) {
        if let idx = draft.tags.firstIndex(of: name) {
            draft.tags.remove(at: idx)
        } else {
            draft.tags.append(name)
        }
        dirty = true
    }

    /// Adds the typed text as a new tag (or reuses an existing one that only
    /// differs by case) and turns it on for this song. There's no separate
    /// tag registry — this tag becomes available to other songs once this
    /// one is saved with it attached, and disappears again once no song
    /// wears it.
    func createTag() {
        let raw = tagQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let name = knownTags.first { $0.caseInsensitiveCompare(raw) == .orderedSame } ?? raw
        if !draft.tags.contains(name) {
            draft.tags.append(name)
            dirty = true
        }
        tagQuery = ""
    }

    // MARK: - Save / back

    /// Whether the canvas was mid-edit (keyboard up) right before the
    /// unsaved-changes sheet opened, so tapping "Stay" can seamlessly resume
    /// typing — mirrors `resumeEditingAfterStripCloses` above.
    private var resumeEditingAfterConfirmCloses = false

    func save() {
        store.upsert(draft, untitledFallback: strings[.untitled])
        draft = store.song(id: draft.id) ?? draft
        dirty = false
        showToast = true
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if Task.isCancelled { return }
            self?.showToast = false
        }
    }

    /// Returns true if it's safe to pop immediately; false if the
    /// save/discard confirmation sheet was opened instead.
    func requestBack() -> Bool {
        guard dirty else { return true }
        resumeEditingAfterConfirmCloses = isEditing
        isEditing = false
        // Actually dismiss the real keyboard (not just hide the chord bar)
        // — otherwise it stays up behind the sheet, overlapping it.
        if keyboardVisible {
            keyboardVisible = false
            blurToken += 1
        }
        confirmOpen = true
        return false
    }

    func stay() {
        confirmOpen = false
        if resumeEditingAfterConfirmCloses {
            resumeEditingAfterConfirmCloses = false
            keyboardVisible = true
            focusCanvas()
        }
    }

    func saveAndBack(_ completion: () -> Void) {
        resumeEditingAfterConfirmCloses = false
        save()
        confirmOpen = false
        completion()
    }

    func discardAndBack(_ completion: () -> Void) {
        resumeEditingAfterConfirmCloses = false
        confirmOpen = false
        dirty = false
        completion()
    }

    // MARK: - Chord bar

    var cursorChordToken: ChordToken? {
        ChordTheory.chordToken(in: draft.body, at: cursor)
    }

    var isVariantMode: Bool { isEditing && cursorChordToken != nil }

    var chordChips: [(name: String, style: ChordChipStyle)] {
        if isEditing, let token = cursorChordToken {
            return ChordTheory.variants(for: token.text).map { name in
                (name, name == token.text ? .active : .outline)
            }
        }
        return ChordTheory.quickChords.map { ($0, .plain) }
    }

    var allChordRows: [(label: String, chords: [String])] {
        ChordTheory.allChordRows(accidentals: accidentalsPreference)
    }

    func toggleAllChords() { allOpen.toggle() }

    /// Inserts a chord at the caret, or replaces the chord the caret is on
    /// (variant mode), then re-focuses the canvas with the caret placed
    /// right after the inserted/replaced text.
    func pickChord(_ name: String) {
        let body = draft.body

        if isEditing, let token = cursorChordToken {
            guard let start = body.index(body.startIndex, offsetBy: token.start, limitedBy: body.endIndex),
                  let end = body.index(body.startIndex, offsetBy: token.end, limitedBy: body.endIndex) else { return }
            draft.body = body.replacingCharacters(in: start..<end, with: name)
            dirty = true
            cursor = token.start + name.count
            focusToken += 1
            return
        }

        let count = body.count
        let insertAt = min(max(cursor, 0), count)
        let startIdx = body.index(body.startIndex, offsetBy: insertAt)
        let before = body[..<startIdx]
        let after = body[startIdx...]

        var insertion = name
        var lead = 0
        if let last = before.last, !last.isWhitespace {
            insertion = " " + insertion
            lead = 1
        }
        if let first = after.first, !first.isWhitespace {
            insertion += " "
        }

        draft.body = String(before) + insertion + String(after)
        dirty = true
        cursor = insertAt + lead + name.count
        focusToken += 1
    }
}
