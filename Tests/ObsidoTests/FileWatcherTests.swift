import Foundation
import Testing
@testable import Obsido

@Suite(.serialized) struct FileWatcherTests {
    private func tempFile(_ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("obsido-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("todo.md")
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }

    private func waitForChange(_ url: URL, timeoutSeconds: Double = 3, trigger: @escaping @Sendable (URL) throws -> Void) async throws -> Bool {
        let changed = AsyncStream<Void>.makeStream()
        let watcher = FileWatcher(url: url, debounceMilliseconds: 50) {
            changed.continuation.yield()
        }
        watcher.start()
        defer { watcher.stop() }

        try await Task.sleep(for: .milliseconds(100))
        try trigger(url)

        let result = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in changed.stream { return true }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        return result
    }

    @Test func firesOnInPlaceWrite() async throws {
        let url = try tempFile("- [ ] a\n")
        let fired = try await waitForChange(url) { url in
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: "- [ ] b\n".data(using: .utf8)!)
            try handle.close()
        }
        #expect(fired, "watcher must fire on in-place append")
    }

    @Test func survivesAtomicReplace() async throws {
        let url = try tempFile("- [ ] a\n")
        let counter = ChangeCounter()
        // ONE watcher must survive TWO atomic replaces (temp file + rename swaps the
        // inode — the pattern that permanently silences naive fd watchers).
        let watcher = FileWatcher(url: url, debounceMilliseconds: 50) {
            Task { await counter.increment() }
        }
        watcher.start()
        defer { watcher.stop() }
        try await Task.sleep(for: .milliseconds(100))

        try "- [ ] replaced\n".data(using: .utf8)!.write(to: url, options: .atomic)
        try await pollUntil(timeoutSeconds: 3) { await counter.count >= 1 }
        #expect(await counter.count >= 1, "watcher must fire on atomic replace")

        try await Task.sleep(for: .milliseconds(200)) // let re-arm settle
        let before = await counter.count
        try "- [ ] replaced again\n".data(using: .utf8)!.write(to: url, options: .atomic)
        try await pollUntil(timeoutSeconds: 3) { await counter.count > before }
        #expect(await counter.count > before, "watcher must keep firing after the inode changed")
    }

    private func pollUntil(timeoutSeconds: Double, _ condition: @Sendable () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}

private actor ChangeCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
