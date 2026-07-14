import Foundation

/// Watches one file for changes via a dispatch file-system source.
///
/// Editors (including our own atomic writes) save via temp-file + rename,
/// which swaps the inode and permanently silences a naive fd watcher. On
/// `.delete`/`.rename` this watcher re-opens the path to arm onto the new
/// inode, retrying briefly if the replacement file hasn't landed yet.
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let debounce: DispatchTimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.allenyjl.obsido.filewatcher")

    private var source: DispatchSourceFileSystemObject?
    private var pendingFire: DispatchWorkItem?
    private var stopped = false

    init(url: URL, debounceMilliseconds: Int = 200, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.debounce = .milliseconds(debounceMilliseconds)
        self.onChange = onChange
    }

    func start() {
        queue.async { [self] in
            stopped = false
            arm()
        }
    }

    func stop() {
        queue.async { [self] in
            stopped = true
            disarm()
            pendingFire?.cancel()
            pendingFire = nil
        }
    }

    // MARK: - Queue-confined

    private func arm() {
        disarm()
        guard !stopped else { return }

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            // File missing (mid-rename or deleted): retry shortly.
            queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
                self?.arm()
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) {
                self.arm() // inode is gone; re-open the path
            }
            self.fireDebounced()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    private func disarm() {
        source?.cancel()
        source = nil
    }

    private func fireDebounced() {
        pendingFire?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        pendingFire = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    deinit {
        source?.cancel()
    }
}
