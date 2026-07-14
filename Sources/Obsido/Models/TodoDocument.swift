import Foundation

/// A markdown file as an ordered list of raw lines.
///
/// Every line keeps its exact original text; `text` re-joins them, so
/// parse → serialize is byte-identical. Parsing only *classifies* lines —
/// it never rewrites them.
public struct TodoDocument: Equatable {
    public struct TaskInfo: Equatable {
        /// The character between the brackets: ' ', 'x', 'X', or a custom status like '-' or '/'.
        public let status: Character
        /// The task text after "] " (empty for a bare "- [ ]").
        public let text: String

        public var isChecked: Bool { status == "x" || status == "X" }
        /// Only plain ' '/'x'/'X' may be toggled; Obsidian custom statuses are read-only.
        public var isToggleable: Bool { status == " " || isChecked }
    }

    public enum Kind: Equatable {
        case task(TaskInfo)
        case heading(Int)
        case blank
        case frontmatter
        case other
    }

    public struct Line: Equatable, Identifiable {
        public let id: UUID
        public internal(set) var raw: String
        public internal(set) var kind: Kind

        init(raw: String) {
            self.id = UUID()
            self.raw = raw
            self.kind = .other
        }
    }

    public private(set) var lines: [Line]

    public init(text: String) {
        lines = text.components(separatedBy: "\n").map(Line.init(raw:))
        reclassify()
    }

    public var text: String {
        lines.map(\.raw).joined(separator: "\n")
    }

    // MARK: - Mutations

    /// Flips ' ' <-> 'x' by replacing the single bracket character.
    /// Returns false (and changes nothing) for non-tasks and custom statuses.
    @discardableResult
    public mutating func toggleTask(at index: Int) -> Bool {
        guard lines.indices.contains(index),
              case .task(let info) = lines[index].kind,
              info.isToggleable
        else { return false }

        var raw = lines[index].raw
        // The prefix before the checkbox is only indent + list marker + spaces,
        // so the first '[' is always the checkbox.
        guard let bracket = raw.firstIndex(of: "[") else { return false }
        let statusIndex = raw.index(after: bracket)
        raw.replaceSubrange(statusIndex...statusIndex, with: info.isChecked ? " " : "x")
        lines[index].raw = raw
        reclassify()
        return true
    }

    public mutating func replaceLine(at index: Int, with raw: String) {
        guard lines.indices.contains(index) else { return }
        lines[index].raw = raw
        reclassify()
    }

    public mutating func insertLine(_ raw: String, at index: Int) {
        guard index >= 0, index <= lines.count else { return }
        lines.insert(Line(raw: raw), at: index)
        reclassify()
    }

    public mutating func removeLine(at index: Int) {
        guard lines.indices.contains(index) else { return }
        lines.remove(at: index)
        reclassify()
    }

    public mutating func moveLine(from source: Int, to destination: Int) {
        guard lines.indices.contains(source), destination >= 0, destination < lines.count else { return }
        let line = lines.remove(at: source)
        lines.insert(line, at: destination)
        reclassify()
    }

    // MARK: - Classification

    private mutating func reclassify() {
        let frontmatter = Self.frontmatterRange(of: lines.map(\.raw))
        for i in lines.indices {
            if let frontmatter, frontmatter.contains(i) {
                lines[i].kind = .frontmatter
            } else {
                lines[i].kind = Self.classify(lines[i].raw)
            }
        }
    }

    /// YAML frontmatter: file starts with "---" and a closing "---" exists.
    /// Both delimiters are part of the block.
    private static func frontmatterRange(of raws: [String]) -> ClosedRange<Int>? {
        guard raws.count >= 2, content(of: raws[0]) == "---" else { return nil }
        for i in 1..<raws.count where content(of: raws[i]) == "---" {
            return 0...i
        }
        return nil
    }

    /// Line content with a trailing CR (from CRLF files) stripped for matching;
    /// the CR stays in `raw` so round-trips remain byte-identical.
    private static func content(of raw: String) -> Substring {
        raw.hasSuffix("\r") ? raw.dropLast() : raw[...]
    }

    // Regex isn't Sendable, but these are immutable after init.
    nonisolated(unsafe) private static let taskRegex = /^([ \t]*)(?:[-*+]|\d{1,9}[.)])( +)\[(.)\](?: (.*))?$/
    nonisolated(unsafe) private static let headingRegex = /^(#{1,6})(?: +(.*))?$/

    private static func classify(_ raw: String) -> Kind {
        let content = content(of: raw)

        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            return .blank
        }
        if let match = content.wholeMatch(of: taskRegex) {
            let status = match.3.first ?? " "
            return .task(TaskInfo(status: status, text: String(match.4 ?? "")))
        }
        if let match = content.wholeMatch(of: headingRegex) {
            return .heading(match.1.count)
        }
        return .other
    }
}
