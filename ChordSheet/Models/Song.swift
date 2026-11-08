import Foundation

struct Song: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var artist: String
    var key: String
    var body: String
    var tags: [String]
    var pinned: Bool
    var dateAdded: Date
    /// Index into `ChordTheory.fontSizes`, remembered per song so each one
    /// reopens at the size it was last left at. Defaults to 4 (24pt), the
    /// app-wide default size, both for brand-new songs and for songs saved
    /// before this field existed.
    var sizeIndex: Int

    init(id: String, title: String, artist: String, key: String, body: String, tags: [String] = [], pinned: Bool = false, dateAdded: Date = Date(), sizeIndex: Int = 4) {
        self.id = id
        self.title = title
        self.artist = artist
        self.key = key
        self.body = body
        self.tags = tags
        self.pinned = pinned
        self.dateAdded = dateAdded
        self.sizeIndex = sizeIndex
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, key, body, tags, pinned, dateAdded, sizeIndex
    }

    // Custom decoding so songs saved before tagging/pinning/dateAdded/
    // sizeIndex existed (no such key in their JSON) still load instead of
    // failing to decode. Missing `dateAdded` falls back to `.distantPast`
    // rather than "now" so pre-existing songs sort as the oldest, not as if
    // freshly added ahead of everything else. Missing `sizeIndex` falls back
    // to the app-wide default of 4 (24pt).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decode(String.self, forKey: .artist)
        key = try c.decode(String.self, forKey: .key)
        body = try c.decode(String.self, forKey: .body)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        dateAdded = try c.decodeIfPresent(Date.self, forKey: .dateAdded) ?? .distantPast
        sizeIndex = try c.decodeIfPresent(Int.self, forKey: .sizeIndex) ?? 4
    }
}
