import Foundation

/// How accidentals should be spelled when a key isn't inherently sharp or flat.
enum Accidentals: String, Codable {
    case auto, sharps, flats
}

/// One token from `ChordTheory.scan` — either a chord or a run of plain text
/// (lyrics, whitespace, or the punctuation immediately around a chord).
struct ChordToken: Equatable {
    let text: String
    let isChord: Bool
    let start: Int
    let end: Int
}

struct ParsedChord: Equatable {
    let pitchClass: Int
    let suffix: String
    let bassPitchClass: Int?
}

/// Swift port of the chord-theory logic from the ChordSheet design prototype
/// (the `class Component extends DCLogic` block in `ChordSheet.dc.html`).
/// Kept as pure, stateless functions so both the chord-highlighted canvas and
/// the chord bar can share the exact same parsing/transposition behavior.
enum ChordTheory {
    static let sharpNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let flatNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    static let majorKeyNames = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    static let minorKeyNames = ["Cm", "C#m", "Dm", "Ebm", "Em", "Fm", "F#m", "Gm", "G#m", "Am", "Bbm", "Bm"]
    static let flatKeys: Set<String> = ["Db", "Eb", "F", "Ab", "Bb", "Cm", "Dm", "Fm", "Gm", "Ebm", "Bbm"]
    static let suffixes = [
        "maj13", "maj9", "maj7", "mmaj7", "m7b5", "madd9", "7sus4", "min7", "sus2", "sus4",
        "add9", "dim7", "m11", "m13", "aug", "dim", "min", "m6", "m7", "m9", "M7",
        "11", "13", "2", "4", "5", "6", "7", "9", "m", "M", "+"
    ]
    static let quickChords = ["C", "D", "E", "F", "G", "A", "B"]
    static let qualityGroups: [(label: String, suffix: String)] = [
        ("MAJ", ""), ("MIN", "m"), ("7", "7"), ("MAJ7", "maj7"), ("M7", "m7"),
        ("SUS2", "sus2"), ("SUS4", "sus4"), ("6", "6"), ("DIM", "dim")
    ]
    static let variantQualities = ["", "m", "7", "maj7", "m7", "sus2", "sus4", "dim", "6"]
    static let fontSizes: [CGFloat] = [15, 17, 19, 21, 24, 27, 30, 33, 36, 39, 42, 45]

    // "H" is the German/Nordic name for B natural (their "B" means what the
    // rest of the world calls Bb) — recognized here as a plain synonym for B
    // so songs written with that convention still parse, highlight, and
    // transpose correctly.
    private static let pcBase: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11, "H": 11]

    private static let chordRegex: NSRegularExpression = {
        let alt = suffixes.map { $0.replacingOccurrences(of: "+", with: "\\+") }.joined(separator: "|")
        let pattern = "^([A-H])(#|b)?((?:\(alt))?)(?:/([A-H])(#|b)?)?$"
        return try! NSRegularExpression(pattern: pattern)
    }()

    private static let keyRootRegex = try! NSRegularExpression(pattern: "^([A-G])(#|b)?$")

    private static func matchGroups(_ regex: NSRegularExpression, in text: String) -> [String?]? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }

    static func pitchClass(letter: Character, accidental: Character?) -> Int {
        let base = pcBase[letter] ?? 0
        let delta = accidental == "#" ? 1 : (accidental == "b" ? -1 : 0)
        return ((base + delta) % 12 + 12) % 12
    }

    /// Parses a single token as a chord, e.g. "G", "F#m7", "Cmaj7/E". Returns nil if it isn't one.
    static func parse(_ token: String) -> ParsedChord? {
        guard let groups = matchGroups(chordRegex, in: token), let rootLetter = groups[1]?.first else { return nil }
        let rootAcc = groups[2]?.first
        let suffix = groups[3] ?? ""
        var bass: Int?
        if let bassLetter = groups[4]?.first {
            bass = pitchClass(letter: bassLetter, accidental: groups[5]?.first)
        }
        return ParsedChord(pitchClass: pitchClass(letter: rootLetter, accidental: rootAcc), suffix: suffix, bassPitchClass: bass)
    }

    static func spell(_ pitchClass: Int, flat: Bool) -> String {
        let a = ((pitchClass % 12) + 12) % 12
        return flat ? flatNames[a] : sharpNames[a]
    }

    static func keyParts(_ key: String) -> (pitchClass: Int, minor: Bool) {
        let minor = key.hasSuffix("m") && !key.contains("maj")
        let root = minor ? String(key.dropLast()) : key
        guard let groups = matchGroups(keyRootRegex, in: root), let letter = groups[1]?.first else {
            return (0, minor)
        }
        return (pitchClass(letter: letter, accidental: groups[2]?.first), minor)
    }

    static func keyName(pitchClass: Int, minor: Bool) -> String {
        let a = ((pitchClass % 12) + 12) % 12
        return minor ? minorKeyNames[a] : majorKeyNames[a]
    }

    static func flatPreferred(forKey key: String, accidentals: Accidentals) -> Bool {
        switch accidentals {
        case .flats: return true
        case .sharps: return false
        case .auto: return flatKeys.contains(key)
        }
    }

    /// Spelled-out key name for the detection panel, e.g. "G" -> "G major",
    /// "Am" -> "A minor" (localized per `language`), with accidentals
    /// rendered as ♭/♯.
    static func longName(_ key: String, language: AppLanguage) -> String {
        let parts = keyParts(key)
        var root = parts.minor ? String(key.dropLast()) : key
        root = root.replacingOccurrences(of: "b", with: "\u{266D}")
            .replacingOccurrences(of: "#", with: "\u{266F}")
        let t = language.strings
        return t.format(parts.minor ? .minorSuffix : .majorSuffix, root)
    }

    /// Transposes a single chord token by `semitones`, re-spelling with sharps or flats.
    static func shift(_ token: String, semitones: Int, flat: Bool) -> String {
        guard let p = parse(token) else { return token }
        var out = spell(p.pitchClass + semitones, flat: flat) + p.suffix
        if let bass = p.bassPitchClass {
            out += "/" + spell(bass + semitones, flat: flat)
        }
        return out
    }

    /// Tokenizes free-form chord-sheet text into chord vs. non-chord runs,
    /// splitting off leading/trailing punctuation (parens, quotes, brackets)
    /// around a chord so e.g. "(G)" highlights only "G".
    static func scan(_ body: String) -> [ChordToken] {
        var out: [ChordToken] = []
        let chars = Array(body)
        let n = chars.count
        let leadSet: Set<Character> = ["(", "\"", "'", "["]
        let trailSet: Set<Character> = [")", "\"", "'", "]", ",", ".", ";", ":", "|"]
        var i = 0

        while i < n {
            if chars[i].isWhitespace {
                var j = i
                while j < n && chars[j].isWhitespace { j += 1 }
                out.append(ChordToken(text: String(chars[i..<j]), isChord: false, start: i, end: j))
                i = j
                continue
            }
            var j = i
            while j < n && !chars[j].isWhitespace { j += 1 }

            var leadEnd = i
            while leadEnd < j && leadSet.contains(chars[leadEnd]) { leadEnd += 1 }
            var trailStart = j
            while trailStart > leadEnd && trailSet.contains(chars[trailStart - 1]) { trailStart -= 1 }
            let core = String(chars[leadEnd..<trailStart])

            if !core.isEmpty, parse(core) != nil {
                if leadEnd > i {
                    out.append(ChordToken(text: String(chars[i..<leadEnd]), isChord: false, start: i, end: leadEnd))
                }
                out.append(ChordToken(text: core, isChord: true, start: leadEnd, end: trailStart))
                if trailStart < j {
                    out.append(ChordToken(text: String(chars[trailStart..<j]), isChord: false, start: trailStart, end: j))
                }
            } else {
                out.append(ChordToken(text: String(chars[i..<j]), isChord: false, start: i, end: j))
            }
            i = j
        }
        return out
    }

    /// Returns the chord token the cursor sits inside/on the edge of, if any.
    static func chordToken(in body: String, at cursor: Int) -> ChordToken? {
        scan(body).first { $0.isChord && cursor >= $0.start && cursor <= $0.end }
    }

    /// Transposes every chord in a sheet, shrinking the whitespace that follows
    /// a chord only when its spelling grows longer (e.g. "E" -> "F#") so it
    /// doesn't run into the next token. Whitespace is never padded back out
    /// when a chord shrinks — doing that from the current text alone (with no
    /// memory of the column width before an earlier transpose already had to
    /// clamp it) is exactly what produced surprise extra gaps after
    /// transposing back and forth. Left untouched, a shrunk chord just leaves
    /// its original spacing in place, which never looks wrong.
    static func shiftBody(_ body: String, semitones: Int, flat: Bool) -> String {
        let segs = scan(body)
        var out = ""
        var i = 0
        while i < segs.count {
            let g = segs[i]
            guard g.isChord else {
                out += g.text
                i += 1
                continue
            }
            let nt = shift(g.text, semitones: semitones, flat: flat)
            out += nt
            let d = nt.count - g.text.count
            var advance = 1
            if i + 1 < segs.count {
                let nx = segs[i + 1]
                if d > 0, !nx.isChord, !nx.text.isEmpty, nx.text.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    out += String(repeating: " ", count: max(1, nx.text.count - d))
                    advance = 2
                }
            }
            i += advance
        }
        return out
    }

    /// Common-quality variants of a chord, for the chord bar's variant mode.
    /// Fixed order: the root itself, its minor, then — only when raising the
    /// root by a semitone actually lands on a sharp (not when the root is
    /// already accidental, and not for E or B, whose neighbor a semitone up
    /// is the natural F or C) — that raised chord major and minor, a
    /// shortcut for reaching sharp chords. The remaining qualities follow,
    /// unordered.
    static func variants(for token: String) -> [String] {
        guard let p = parse(token) else { return [] }
        let flat = token.contains("b")
        let root = spell(p.pitchClass, flat: flat)
        let rootHasAccidental = root.contains("#") || root.contains("b")
        let raisedRoot = sharpNames[(p.pitchClass + 1) % 12]

        var list = [root, root + "m"]
        if !rootHasAccidental && raisedRoot.contains("#") {
            list.append(raisedRoot)
            list.append(raisedRoot + "m")
        }
        for quality in variantQualities where quality != "" && quality != "m" {
            list.append(root + quality)
        }

        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    /// Rows for the "All chords" grid: one row per quality, one chord per root.
    static func allChordRows(accidentals: Accidentals) -> [(label: String, chords: [String])] {
        let roots = accidentals == .flats ? flatNames : sharpNames
        return qualityGroups.map { label, suffix in (label, roots.map { $0 + suffix }) }
    }

    // MARK: - Key detection

    private enum TriadQuality { case major, minor, diminished }

    /// Buckets a chord's suffix into the triad quality that matters for key-fitting.
    /// Sevenths/sus/add-whatever all read as "major-family" here — what matters is
    /// whether the suffix marks the chord minor (or diminished), not its color tones.
    private static func triadQuality(ofSuffix suffix: String) -> TriadQuality {
        if suffix.contains("dim") { return .diminished }
        if suffix.hasPrefix("m") && !suffix.hasPrefix("maj") { return .minor }
        return .major
    }

    /// Diatonic triads of a major key, as (semitone offset from tonic, expected quality).
    private static let majorDegrees: [Int: TriadQuality] = [
        0: .major, 2: .minor, 4: .minor, 5: .major, 7: .major, 9: .minor, 11: .diminished
    ]
    /// Diatonic triads of a natural-minor key. The fifth (offset 7) is handled
    /// separately below, since folk/pop songs in a minor key routinely borrow the
    /// harmonic-minor major dominant (e.g. E7 in A minor) rather than the natural v.
    private static let minorDegrees: [Int: TriadQuality] = [
        0: .minor, 2: .diminished, 3: .major, 5: .minor, 8: .major, 10: .major
    ]

    /// Every (root, major/minor) candidate's diatonic fit score for a chord
    /// sheet, best first. Shared by both the silent new-song auto-detect and
    /// the manual "Detect key" button, so they can't disagree on a guess.
    private static func scoredKeyCandidates(from body: String) -> [(name: String, score: Double)]? {
        let occurrences: [(pitchClass: Int, quality: TriadQuality)] = scan(body)
            .filter { $0.isChord }
            .compactMap { token in
                guard let parsed = parse(token.text) else { return nil }
                return (parsed.pitchClass, triadQuality(ofSuffix: parsed.suffix))
            }
        guard !occurrences.isEmpty else { return nil }

        var frequency = [Int: Int]()
        for o in occurrences { frequency[o.pitchClass, default: 0] += 1 }
        let firstPitchClass = occurrences.first?.pitchClass
        let lastPitchClass = occurrences.last?.pitchClass

        // A relative major/minor pair (e.g. D major vs. B minor) shares the exact
        // same diatonic chord palette, so the fit score alone is always tied.
        // Break ties deterministically — proportional to how often each candidate
        // tonic is actually played (no arbitrary "first max found" pick), plus
        // whether it's the first/last chord (songs usually start/end on the
        // tonic), with a hair of preference for major as the more common default.
        var candidates: [(name: String, score: Double)] = []
        for tonic in 0..<12 {
            for isMinor in [false, true] {
                var score = 0.0
                for o in occurrences {
                    let offset = ((o.pitchClass - tonic) % 12 + 12) % 12
                    if isMinor && offset == 7 {
                        // Harmonic-minor dominant allowance: both v and V fit fully.
                        score += (o.quality == .major || o.quality == .minor) ? 1.0 : 0.4
                    } else if let expected = (isMinor ? minorDegrees : majorDegrees)[offset] {
                        score += (expected == o.quality) ? 1.0 : 0.4
                    }
                    // An offset with no diatonic entry is a chromatic chord — 0 credit.
                }
                score += 0.8 * Double(frequency[tonic] ?? 0)
                if firstPitchClass == tonic { score += 1.5 }
                if lastPitchClass == tonic { score += 1.5 }
                if !isMinor { score += 0.05 }
                candidates.append((keyName(pitchClass: tonic, minor: isMinor), score))
            }
        }
        return candidates.sorted { $0.score > $1.score }
    }

    /// Guesses the song's key from the chords actually used in its body — diatonic
    /// chord-set matching (which key's palette best explains these chords), not a
    /// naive "first chord" or "last chord" guess. Returns nil if there's nothing to
    /// go on (no parseable chords in the body).
    static func detectKey(from body: String) -> String? {
        scoredKeyCandidates(from: body)?.first?.name
    }

    struct KeyGuess {
        let name: String
        /// A close runner-up worth mentioning (e.g. the relative minor of a
        /// detected major key), when the fit scores were too near to call.
        let alternateName: String?
    }

    /// The manual "Detect key" button's version of `detectKey`: requires at
    /// least 3 chords (a couple of chords isn't enough signal to bother the
    /// user with a guess) and surfaces a close alternative instead of
    /// silently picking one when two candidates are nearly tied.
    static func detectKeyGuess(from body: String) -> KeyGuess? {
        let chordCount = scan(body).filter { $0.isChord }.count
        guard chordCount >= 3, let candidates = scoredKeyCandidates(from: body), let best = candidates.first else {
            return nil
        }
        let runnerUp = candidates.first { $0.name != best.name }
        let alternateName = (runnerUp.map { best.score - $0.score < 2.2 }) == true ? runnerUp?.name : nil
        return KeyGuess(name: best.name, alternateName: alternateName)
    }
}
