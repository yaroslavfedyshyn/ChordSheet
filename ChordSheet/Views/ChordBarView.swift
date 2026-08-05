import SwiftUI

/// The context-sensitive bar docked above the keyboard while editing: a
/// quick-insert chip row (or, when the caret sits on a chord, variants of
/// that chord to swap in), plus an "All chords" grid for anything else.
struct ChordBarView: View {
    @ObservedObject var vm: SongEditorViewModel
    @EnvironmentObject private var accentPreference: AccentPreference
    @EnvironmentObject private var languagePreference: LanguagePreference

    var body: some View {
        VStack(spacing: 0) {
            modeRow
            if vm.allOpen {
                allChordsGrid
                doneRow
            } else {
                chipsRow
            }
        }
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .top)
        .transition(.move(edge: .bottom))
    }

    private var modeRow: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(vm.isVariantMode ? Theme.accent : Theme.muted)
                    .frame(width: 6, height: 6)
                Text(modeLabel)
                    .font(AppFont.mono(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(vm.isVariantMode ? Theme.accent : Theme.muted)
            }
            Spacer()
            Button(action: vm.hideKeyboard) {
                HStack(spacing: 6) {
                    Text(languagePreference.t[.hideKeyboard])
                        .font(AppFont.sans(12.5))
                        .foregroundColor(Theme.muted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toggleKeyboardButton")
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 32)
    }

    private var modeLabel: String {
        if vm.isVariantMode, let token = vm.cursorChordToken {
            return "\(token.text) · \(languagePreference.t[.variants])"
        }
        return languagePreference.t[.insertChord]
    }

    private var chipsRow: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.chordChips, id: \.name) { chip in
                        ChordChipButton(name: chip.name, style: chip.style, fixedWidth: quickChipWidth(for: geo.size.width)) {
                            vm.pickChord(chip.name)
                        }
                    }
                    Button(action: vm.toggleAllChords) {
                        Text(languagePreference.t[.allChords])
                            .font(AppFont.sans(13.5, weight: .medium))
                            .foregroundColor(Theme.muted)
                            .frame(height: 44)
                            .padding(.horizontal, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.chordChip)
                                    .strokeBorder(Theme.divider, style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("allChordsToggle")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 56)
    }

    /// Quick-insert chips (the fixed C D E F G A B set) size themselves to
    /// exactly fill the screen on wider/modern iPhones, so all 7 are visible
    /// without scrolling — only "All chords" needs a scroll to reach it.
    /// Smaller screens (SE, mini) fall back to natural sizing + scroll
    /// rather than squeezing the chips uncomfortably small; variant-mode
    /// chips (variable-length names like "F#m7") always size naturally.
    private func quickChipWidth(for availableWidth: CGFloat) -> CGFloat? {
        guard !vm.isVariantMode, availableWidth >= 390 else { return nil }
        let count = CGFloat(ChordTheory.quickChords.count)
        let interChipSpacing: CGFloat = 8
        let outerPadding: CGFloat = 32
        let usable = availableWidth - outerPadding - interChipSpacing * (count - 1)
        return usable / count
    }

    private var allChordsGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vm.allChordRows, id: \.label) { row in
                    HStack(alignment: .center, spacing: 10) {
                        Text(row.label)
                            .font(AppFont.mono(10, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(Theme.muted)
                            .frame(width: 42, alignment: .leading)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(row.chords, id: \.self) { chordName in
                                    Button {
                                        vm.pickChord(chordName)
                                    } label: {
                                        Text(chordName)
                                            .font(AppFont.mono(15, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .frame(minWidth: 52)
                                            .frame(height: 38)
                                            .padding(.horizontal, 12)
                                            .background(Theme.surface2)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("gridChord_\(row.label)_\(chordName)")
                                }
                            }
                            .padding(.trailing, 18)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.vertical, 5)
                }
            }
            .padding(.bottom, 10)
        }
        .frame(maxHeight: 196)
    }

    private var doneRow: some View {
        Button(action: vm.toggleAllChords) {
            Text(languagePreference.t[.done])
                .font(AppFont.sans(14, weight: .semibold))
                .foregroundColor(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chordChip))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct ChordChipButton: View {
    let name: String
    let style: ChordChipStyle
    var fixedWidth: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let fixedWidth {
                    label.frame(width: fixedWidth, height: 44)
                } else {
                    label
                        .frame(minWidth: 20)
                        .frame(height: 44)
                        .padding(.horizontal, 15)
                }
            }
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chordChip))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.chordChip)
                    .strokeBorder(style == .outline ? Theme.accent.opacity(0.42) : .clear, lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chip_\(name)")
    }

    private var label: some View {
        Text(name)
            .font(AppFont.mono(16.5, weight: .bold))
            .foregroundColor(style == .active ? .white : Theme.accent)
    }

    private var background: Color {
        switch style {
        case .active: return Theme.accent
        case .outline: return .clear
        case .plain: return Theme.surface2
        }
    }
}
