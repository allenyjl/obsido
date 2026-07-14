import Foundation
import Testing
@testable import Obsido

@Suite struct DocumentFileTests {
    private func tempFile(_ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("obsido-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("todo.md")
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }

    @Test func readParsesContents() throws {
        let url = try tempFile("- [ ] alpha\n")
        var file = DocumentFile(url: url)
        let doc = try file.read()
        guard case .task = doc.lines[0].kind else {
            Issue.record("expected task")
            return
        }
    }

    @Test func writePersistsMutation() throws {
        let url = try tempFile("- [ ] alpha\n")
        var file = DocumentFile(url: url)
        var doc = try file.read()
        _ = doc.toggleTask(at: 0)
        try file.write(doc)
        #expect(try String(contentsOf: url, encoding: .utf8) == "- [x] alpha\n")
    }

    @Test func writeDetectsExternalConflictAndDoesNotClobber() throws {
        let url = try tempFile("- [ ] alpha\n")
        var file = DocumentFile(url: url)
        var doc = try file.read()
        _ = doc.toggleTask(at: 0)

        let external = "- [ ] alpha\n- [ ] added by obsidian\n"
        try external.data(using: .utf8)!.write(to: url)

        #expect(throws: DocumentFile.Error.conflict) {
            try file.write(doc)
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == external)
    }

    @Test func writeAfterRereadSucceeds() throws {
        let url = try tempFile("- [ ] alpha\n")
        var file = DocumentFile(url: url)
        _ = try file.read()
        try "- [ ] beta\n".data(using: .utf8)!.write(to: url)

        var doc = try file.read()
        _ = doc.toggleTask(at: 0)
        try file.write(doc)
        #expect(try String(contentsOf: url, encoding: .utf8) == "- [x] beta\n")
    }

    @Test func readMissingFileThrows() {
        var file = DocumentFile(url: URL(fileURLWithPath: "/nonexistent/obsido/todo.md"))
        #expect(throws: (any Swift.Error).self) {
            try file.read()
        }
    }

    @Test func consecutiveWritesWithoutRereadSucceed() throws {
        let url = try tempFile("- [ ] a\n- [ ] b\n")
        var file = DocumentFile(url: url)
        var doc = try file.read()
        _ = doc.toggleTask(at: 0)
        try file.write(doc)
        _ = doc.toggleTask(at: 1)
        try file.write(doc)
        #expect(try String(contentsOf: url, encoding: .utf8) == "- [x] a\n- [x] b\n")
    }
}
