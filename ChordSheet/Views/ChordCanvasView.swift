import SwiftUI
import UIKit

/// Hosts the chord-sheet body in a native `UITextView`, styling chord tokens
/// bold+accent and lyrics muted (ported from the design's tokenizer-driven
/// "mirror div behind a transparent textarea" trick — a real attributed
/// `UITextView` gets the same look natively, without the overlay hack).
struct ChordCanvasView: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursor: Int
    var fontSize: CGFloat
    var accentTheme: AccentTheme
    var focusToken: Int
    var blurToken: Int
    var onBeginEditing: () -> Void
    var onEndEditing: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.tintColor = accentTheme.uiColor
        context.coordinator.applyHighlighting(text: text, fontSize: fontSize, accentTheme: accentTheme, to: textView)
        context.coordinator.lastFontSize = fontSize
        context.coordinator.lastAccentTheme = accentTheme
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text || context.coordinator.lastFontSize != fontSize || context.coordinator.lastAccentTheme != accentTheme {
            let saved = uiView.selectedRange
            uiView.tintColor = accentTheme.uiColor
            context.coordinator.applyHighlighting(text: text, fontSize: fontSize, accentTheme: accentTheme, to: uiView)
            context.coordinator.lastFontSize = fontSize
            context.coordinator.lastAccentTheme = accentTheme
            let len = (uiView.text as NSString).length
            uiView.selectedRange = NSRange(location: min(saved.location, len), length: 0)
            context.coordinator.lastAppliedCursor = uiView.selectedRange.location
        }

        if context.coordinator.lastAppliedCursor != cursor {
            let len = (uiView.text as NSString).length
            let loc = min(max(cursor, 0), len)
            uiView.selectedRange = NSRange(location: loc, length: 0)
            context.coordinator.lastAppliedCursor = loc
        }

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
        }
        if context.coordinator.lastBlurToken != blurToken {
            context.coordinator.lastBlurToken = blurToken
            if uiView.isFirstResponder { uiView.resignFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let unwrapped = uiView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let width = max(unwrapped.width, proposal.width ?? unwrapped.width)
        let height = max(unwrapped.height, proposal.height ?? unwrapped.height)
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    static func highlightedText(_ text: String, fontSize: CGFloat, accentTheme: AccentTheme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * 0.34
        let chordFont = AppFont.monoUIFont(fontSize, weight: .bold)
        let lyricFont = AppFont.monoUIFont(fontSize, weight: .regular)
        let accentColor = accentTheme.uiColor
        let mutedColor = UIColor(named: "Muted") ?? .gray

        for seg in ChordTheory.scan(text) {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: seg.isChord ? chordFont : lyricFont,
                .foregroundColor: seg.isChord ? accentColor : mutedColor,
                .paragraphStyle: paragraph
            ]
            result.append(NSAttributedString(string: seg.text, attributes: attrs))
        }
        if text.isEmpty {
            result.append(NSAttributedString(string: "", attributes: [.font: lyricFont, .paragraphStyle: paragraph]))
        }
        return result
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ChordCanvasView
        var lastFontSize: CGFloat = -1
        var lastAccentTheme: AccentTheme?
        var lastFocusToken = 0
        var lastBlurToken = 0
        var lastAppliedCursor = -1

        init(_ parent: ChordCanvasView) {
            self.parent = parent
        }

        func applyHighlighting(text: String, fontSize: CGFloat, accentTheme: AccentTheme, to textView: UITextView) {
            textView.attributedText = ChordCanvasView.highlightedText(text, fontSize: fontSize, accentTheme: accentTheme)
        }

        func textViewDidChange(_ textView: UITextView) {
            let saved = textView.selectedRange
            parent.text = textView.text
            applyHighlighting(text: textView.text, fontSize: parent.fontSize, accentTheme: parent.accentTheme, to: textView)
            lastFontSize = parent.fontSize
            lastAccentTheme = parent.accentTheme
            let len = (textView.text as NSString).length
            textView.selectedRange = NSRange(location: min(saved.location, len), length: 0)
            lastAppliedCursor = textView.selectedRange.location
            parent.cursor = textView.selectedRange.location
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            lastAppliedCursor = textView.selectedRange.location
            parent.cursor = textView.selectedRange.location
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onBeginEditing()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEndEditing()
        }
    }
}
