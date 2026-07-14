import AppKit
import Foundation

/// Owns the currently displayed file: loads it, watches it, and funnels every
/// mutation through a conflict-checked atomic write.
///
/// Write policy (see spec): each user action writes immediately — never
/// batched. On conflict (file changed on disk since last read) the mutation is
/// dropped and the file reloaded; with a local-only vault this is rare and the
/// re-render keeps the UI truthful.
@MainActor
final class DocumentStore: ObservableObject {
    enum State {
        case noFile
        case loaded
        case missing(path: String)
    }

    @Published private(set) var document: TodoDocument?
    @Published private(set) var state: State = .noFile

    private var file: DocumentFile?
    private var watcher: FileWatcher?

    func open(path: String?) {
        watcher?.stop()
        watcher = nil
        file = nil
        document = nil

        guard let path else {
            state = .noFile
            return
        }
        let url = URL(fileURLWithPath: path)
        file = DocumentFile(url: url)
        reload()

        let watcher = FileWatcher(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshIfDiskChanged()
            }
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Re-read when the bytes on disk differ from what we know (skips events
    /// from our own atomic saves).
    func refreshIfDiskChanged() {
        guard let file else { return }
        if case .missing = state {
            reload() // file may have reappeared
            return
        }
        if file.isDiskChanged() {
            reload()
        }
    }

    private func reload() {
        guard file != nil else { return }
        do {
            document = try file!.read()
            state = .loaded
        } catch {
            document = nil
            state = .missing(path: file!.url.path)
        }
    }

    // MARK: - Mutations (each writes immediately)

    func index(of id: UUID) -> Int? {
        document?.lines.firstIndex { $0.id == id }
    }

    func line(_ id: UUID) -> TodoDocument.Line? {
        document?.lines.first { $0.id == id }
    }

    func toggle(id: UUID) {
        apply { doc in
            guard let i = doc.lines.firstIndex(where: { $0.id == id }) else { return }
            doc.toggleTask(at: i)
        }
    }

    func commit(id: UUID, raw: String) {
        guard line(id)?.raw != raw else { return }
        apply { doc in
            guard let i = doc.lines.firstIndex(where: { $0.id == id }) else { return }
            doc.replaceLine(at: i, with: raw)
        }
    }

    /// Commits `draft` to the line, then inserts a new line after it.
    /// Returns the new line's id for focus hand-off.
    func commitAndInsertBelow(id: UUID, draft: String, newRaw: String) -> UUID? {
        var newID: UUID?
        apply { doc in
            guard let i = doc.lines.firstIndex(where: { $0.id == id }) else { return }
            if doc.lines[i].raw != draft {
                doc.replaceLine(at: i, with: draft)
            }
            doc.insertLine(newRaw, at: i + 1)
            newID = doc.lines[i + 1].id
        }
        return newID
    }

    /// Removes a line (backspace on empty). Returns the id of the line that
    /// precedes it, for focus hand-off.
    func remove(id: UUID) -> UUID? {
        var previousID: UUID?
        apply { doc in
            guard let i = doc.lines.firstIndex(where: { $0.id == id }) else { return }
            previousID = i > 0 ? doc.lines[i - 1].id : nil
            doc.removeLine(at: i)
        }
        return previousID
    }

    func move(from source: IndexSet, to destination: Int) {
        guard let first = source.first else { return }
        apply { doc in
            // List's onMove semantics: destination is the insertion index
            // *before* removal.
            let target = destination > first ? destination - 1 : destination
            doc.moveLine(from: first, to: target)
        }
    }

    /// Appends a task at the end (before a trailing blank final line, so files
    /// ending in "\n" stay that way). Returns the new line's id.
    @discardableResult
    func appendTask(text: String) -> UUID? {
        var newID: UUID?
        apply { doc in
            var insertAt = doc.lines.count
            if let last = doc.lines.last, last.raw.isEmpty, doc.lines.count > 1 {
                insertAt -= 1
            }
            doc.insertLine("- [ ] \(text)", at: insertAt)
            newID = doc.lines[insertAt].id
        }
        return newID
    }

    private func apply(_ mutation: (inout TodoDocument) -> Void) {
        guard var doc = document, file != nil else { return }
        let before = doc
        mutation(&doc)
        guard doc != before else { return }
        do {
            try file!.write(doc)
            document = doc
        } catch {
            // Conflict or IO failure: drop the mutation, trust the disk.
            reload()
        }
    }

    // MARK: - Obsidian

    func openInObsidian() {
        guard let file else { return }
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: file.url.path)]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}
