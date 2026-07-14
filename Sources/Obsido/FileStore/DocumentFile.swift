import Foundation

/// Reads and writes one markdown file with conflict detection.
///
/// `write` refuses to save (throws `.conflict`) if the file on disk no longer
/// matches the bytes last read — e.g. Obsidian edited it in between. Callers
/// must re-`read` and re-apply. All writes are atomic.
struct DocumentFile {
    enum Error: Swift.Error, Equatable {
        case conflict
        case notUTF8
    }

    let url: URL
    private(set) var lastKnown: Data?

    init(url: URL) {
        self.url = url
    }

    mutating func read() throws -> TodoDocument {
        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw Error.notUTF8
        }
        lastKnown = data
        return TodoDocument(text: string)
    }

    mutating func write(_ document: TodoDocument) throws {
        let onDisk = try Data(contentsOf: url)
        guard onDisk == lastKnown else {
            throw Error.conflict
        }
        let data = Data(document.text.utf8)
        try data.write(to: url, options: .atomic)
        lastKnown = data
    }

    /// True when the bytes on disk differ from the last read/write —
    /// used to ignore watcher events caused by our own atomic saves.
    func isDiskChanged() -> Bool {
        (try? Data(contentsOf: url)) != lastKnown
    }
}
