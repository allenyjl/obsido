import SwiftUI

/// Builds the rendered (unfocused) representation of a line.
///
/// Base inline markdown (bold/italic/code/links) goes through Foundation's
/// markdown parser; Obsidian-specific syntax that nothing in the ecosystem
/// renders (==highlights==, [[wikilinks]], #tags) is styled by regex on top.
enum MarkdownStyler {
    static func styledInline(_ source: String, checked: Bool = false) -> AttributedString {
        var result = inlineParsed(highlightAware(source))
        if checked {
            result.strikethroughStyle = .single
            result.foregroundColor = .secondary
        }
        return result
    }

    static func styledHeading(_ text: String, level: Int) -> AttributedString {
        var result = inlineParsed(text)
        switch level {
        case 1: result.font = .system(.title3, weight: .bold)
        case 2: result.font = .system(.headline, weight: .semibold)
        default: result.font = .system(.subheadline, weight: .semibold)
        }
        return result
    }

    // MARK: - Internals

    /// Foundation's parser drops unknown syntax like `==`; pre-convert
    /// highlights into bold so emphasis survives, then color them after.
    private static func highlightAware(_ source: String) -> String {
        source
    }

    private static func inlineParsed(_ source: String) -> AttributedString {
        var attributed: AttributedString
        do {
            attributed = try AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            attributed = AttributedString(source)
        }
        styleObsidianExtras(&attributed)
        return attributed
    }

    /// Colors ==highlights==, [[wikilinks]] and #tags in place (the delimiters
    /// stay visible — this is a live-preview-lite, not a full renderer).
    private static func styleObsidianExtras(_ attributed: inout AttributedString) {
        let text = String(attributed.characters)

        style(pattern: /==([^=]+)==/, in: text, attributed: &attributed) { run in
            run.backgroundColor = Color.yellow.opacity(0.35)
        }
        style(pattern: /\[\[([^\]]+)\]\]/, in: text, attributed: &attributed) { run in
            run.foregroundColor = .accentColor
        }
        style(pattern: /(?:^|\s)(#[\p{L}\p{N}_\/-]+)/, in: text, attributed: &attributed) { run in
            run.foregroundColor = .purple
        }
    }

    private static func style(
        pattern: some RegexComponent,
        in text: String,
        attributed: inout AttributedString,
        apply: (inout AttributedSubstring) -> Void
    ) {
        for match in text.matches(of: pattern) {
            guard let lower = AttributedString.Index(match.range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(match.range.upperBound, within: attributed)
            else { continue }
            var run = attributed[lower..<upper]
            apply(&run)
            attributed.replaceSubrange(lower..<upper, with: run)
        }
    }
}
