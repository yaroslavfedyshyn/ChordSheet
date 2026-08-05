import Foundation
import Combine

/// The main list's sort order, from the design's sidebar "SORT" section —
/// only the 3 options the app actually offers (the design also has
/// "Recently edited" and "By key", which aren't implemented here).
enum SongSortOrder: String, CaseIterable, Identifiable {
    case alphabetical, mostRecent, oldestFirst

    var id: String { rawValue }
}

/// Loads/saves songs as JSON in the app's Documents directory. First launch
/// starts with an empty library — the user fills it in with their own songs.
@MainActor
final class SongStore: ObservableObject {
    @Published private(set) var songs: [Song]

    /// The user's chosen sort order for the main list, persisted across
    /// launches the same way `AccentPreference`/`AppearancePreference` are.
    @Published var sortOrder: SongSortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey) }
    }

    private static let sortOrderKey = "sortOrder"

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        if let raw = UserDefaults.standard.string(forKey: Self.sortOrderKey), let saved = SongSortOrder(rawValue: raw) {
            self.sortOrder = saved
        } else {
            self.sortOrder = .alphabetical
        }
        if let loaded = Self.load(from: url) {
            self.songs = loaded
        } else {
            self.songs = []
            save()
        }
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("songs.json")
    }

    private static func load(from url: URL) -> [Song]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Song].self, from: data)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Every tag name currently attached to at least one song, deduplicated
    /// case-insensitively and sorted for stable display. There's no separate
    /// tag management in this app — a tag exists only as long as some song
    /// wears it, and disappears the moment none do.
    var allTags: [String] {
        var canonical: [String: String] = [:]
        for song in songs {
            for tag in song.tags {
                let key = tag.lowercased()
                if canonical[key] == nil { canonical[key] = tag }
            }
        }
        return canonical.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// The spelling to use for a typed tag name — an existing tag differing
    /// only by case if one is already attached to some song, otherwise the
    /// name as typed (which becomes a real tag once attached to a song).
    func canonicalTagName(for name: String) -> String {
        allTags.first { $0.caseInsensitiveCompare(name) == .orderedSame } ?? name
    }

    func song(id: String) -> Song? {
        songs.first { $0.id == id }
    }

    /// `untitledFallback` is the current UI language's translation of
    /// "Untitled song" — resolved by the caller (a View, which has access to
    /// `LanguagePreference`) rather than here, since this store has no
    /// language of its own.
    func upsert(_ song: Song, untitledFallback: String) {
        var s = song
        if s.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.title = untitledFallback
        }
        if s.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.artist = "Unknown"
        }
        if let idx = songs.firstIndex(where: { $0.id == s.id }) {
            songs[idx] = s
        } else {
            songs.append(s)
        }
        save()
    }

    func delete(id: String) {
        songs.removeAll { $0.id == id }
        save()
    }

    func togglePin(id: String) {
        guard let idx = songs.firstIndex(where: { $0.id == id }) else { return }
        songs[idx].pinned.toggle()
        save()
    }

    var hasPinnedSongs: Bool { songs.contains { $0.pinned } }

    func unpinAll() {
        guard hasPinnedSongs else { return }
        for idx in songs.indices { songs[idx].pinned = false }
        save()
    }

    static func newSongID() -> String {
        "n\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    func makeBackup() -> LibraryBackup {
        LibraryBackup(songs: songs)
    }

    /// Wholesale replace, preserving the backup's own song order.
    func replaceLibrary(with backup: LibraryBackup) {
        songs = backup.songs.map { $0.asSong }
        save()
    }
}
