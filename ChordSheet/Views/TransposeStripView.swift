import SwiftUI

/// The horizontal strip of key pills shown under the header when the key
/// badge is tapped. Tapping a pill transposes every chord in the sheet; the
/// "Detect key" button offers a best-guess key from the chords actually
/// typed, without touching them.
struct TransposeStripView: View {
    @ObservedObject var vm: SongEditorViewModel
    @EnvironmentObject private var accentPreference: AccentPreference
    @EnvironmentObject private var languagePreference: LanguagePreference

    private var pills: [(semitones: Int, name: String, isCurrent: Bool)] { vm.transposePills }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(languagePreference.t[.transposeHeader])
                    .font(AppFont.mono(10, weight: .bold))
                    .tracking(1.3)
                    .foregroundColor(Theme.muted)
                Spacer()
                detectKeyButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            if let detection = vm.keyDetection {
                detectionPanel(detection)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pills, id: \.semitones) { pill in
                            Button {
                                vm.transpose(semitones: pill.semitones)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(pill.name)
                                        .font(AppFont.mono(17, weight: .bold))
                                        .foregroundColor(pill.isCurrent ? .white : Theme.accent)
                                    Text(pill.isCurrent ? languagePreference.t[.now] : stepLabel(for: pill.semitones))
                                        .font(AppFont.mono(9.5, weight: .medium))
                                        .tracking(0.6)
                                        .foregroundColor(pill.isCurrent ? Color.white.opacity(0.72) : Theme.muted)
                                }
                                .frame(width: 58, height: 56)
                                .background(pill.isCurrent ? Theme.accent : Theme.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.transposePill))
                                .shadow(color: pill.isCurrent ? Theme.accent.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("transposePill_\(pill.semitones)")
                            .id(pill.semitones)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }
                .onAppear {
                    proxy.scrollTo(0, anchor: .center)
                }
            }
        }
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .bottom)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var detectKeyButton: some View {
        Button(action: vm.detectKey) {
            HStack(spacing: 7) {
                Image(systemName: "tuningfork")
                    .font(.system(size: 12, weight: .semibold))
                Text(languagePreference.t[.detectKey])
                    .font(AppFont.sans(13.5, weight: .semibold))
            }
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detectKeyButton")
    }

    private func detectionPanel(_ detection: KeyDetectionResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(detectionLine(detection))
                    .font(AppFont.sans(14.5, weight: .medium))
                    .foregroundColor(Theme.ink)
                if let note = detectionNote(detection), !note.isEmpty {
                    Text(note)
                        .font(AppFont.sans(12.5))
                        .foregroundColor(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            if !detection.none, let name = detection.name, !detection.sameAsCurrent {
                Button {
                    vm.applyDetectedKey()
                } label: {
                    Text(languagePreference.t[.fixKey])
                        .font(AppFont.sans(14.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fixKeyButton_\(name)")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .transition(.opacity)
    }

    private func detectionLine(_ detection: KeyDetectionResult) -> String {
        let t = languagePreference.t
        if detection.none { return t[.notEnough] }
        guard let name = detection.name else { return "" }
        let longName = ChordTheory.longName(name, language: languagePreference.language)
        if detection.sameAsCurrent {
            return t.format(.fits, longName)
        }
        return t.format(.looks, longName)
    }

    /// Pill sublabel in "step" units, where a semitone is a half step (0.5)
    /// and a whole tone is a full step (1) — standard music-theory
    /// terminology. The transposition itself is unchanged (still exactly one
    /// semitone per adjacent pill); only this label's units differ from a
    /// raw semitone count.
    private func stepLabel(for semitones: Int) -> String {
        let magnitude = abs(Double(semitones)) * 0.5
        let text = magnitude.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", magnitude)
            : String(format: "%.1f", magnitude)
        return (semitones > 0 ? "+" : "-") + text
    }

    private func detectionNote(_ detection: KeyDetectionResult) -> String? {
        let t = languagePreference.t
        if detection.none { return t[.notEnoughNote] }
        if let close = detection.alternateName {
            return t.format(.couldBe, ChordTheory.longName(close, language: languagePreference.language))
        }
        if detection.sameAsCurrent { return nil }
        return t.format(.badgeSays, vm.draft.key)
    }
}
