import Foundation

/// A snapshot of one song for backup purposes, kept separate from `Song`
/// itself so a future change to the live model's shape doesn't silently
/// break decoding of backups written by older app versions.
struct SongBackupDTO: Codable {
    let id: String
    let title: String
    let artist: String
    let key: String
    let body: String
    let tags: [String]
    let pinned: Bool
    let dateAdded: Date

    init(song: Song) {
        id = song.id
        title = song.title
        artist = song.artist
        key = song.key
        body = song.body
        tags = song.tags
        pinned = song.pinned
        dateAdded = song.dateAdded
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, key, body, tags, pinned, dateAdded
    }

    // Backups exported before `dateAdded` existed won't have that key —
    // fall back to `.distantPast` (oldest) rather than "now" so importing
    // an old backup doesn't make every song look freshly added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decode(String.self, forKey: .artist)
        key = try c.decode(String.self, forKey: .key)
        body = try c.decode(String.self, forKey: .body)
        tags = try c.decode([String].self, forKey: .tags)
        pinned = try c.decode(Bool.self, forKey: .pinned)
        dateAdded = try c.decodeIfPresent(Date.self, forKey: .dateAdded) ?? .distantPast
    }

    var asSong: Song {
        Song(id: id, title: title, artist: artist, key: key, body: body, tags: tags, pinned: pinned, dateAdded: dateAdded)
    }
}

/// The full-library export/import payload. `schemaVersion` lets a future
/// format change be detected (and rejected with a clear message) instead of
/// silently misreading an old or new file.
struct LibraryBackup: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let songs: [SongBackupDTO]

    init(songs: [Song], exportedAt: Date = Date()) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.songs = songs.map(SongBackupDTO.init)
    }

    enum ImportError: LocalizedError {
        case corrupt
        case unsupportedSchemaVersion(Int)

        var errorDescription: String? {
            switch self {
            case .corrupt:
                return "That file doesn't look like a Chord Sheet backup."
            case .unsupportedSchemaVersion:
                return "This backup was made with a newer version of Chord Sheet and can't be opened here."
            }
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    /// Checks `schemaVersion` before attempting to decode `songs`, so a
    /// backup from a newer, incompatible schema is reported as
    /// "unsupported version" rather than lumped in with a plain corrupt file.
    static func decode(from data: Data) throws -> LibraryBackup {
        struct VersionProbe: Decodable { let schemaVersion: Int }
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: data) else {
            throw ImportError.corrupt
        }
        guard probe.schemaVersion <= currentSchemaVersion else {
            throw ImportError.unsupportedSchemaVersion(probe.schemaVersion)
        }
        guard let backup = try? decoder.decode(LibraryBackup.self, from: data) else {
            throw ImportError.corrupt
        }
        return backup
    }
}
