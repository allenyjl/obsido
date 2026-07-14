import AppKit
import KeyboardShortcuts
import SwiftUI

@main
struct ObsidoMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    private let settings = AppSettings()
    private let store = DocumentStore()
    private let controller = PopoverController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Obsido")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        store.open(path: settings.selectedPath)

        controller.applyPin = { [weak self] pinned in
            // .applicationDefined keeps the popover open on outside clicks.
            self?.popover.behavior = pinned ? .applicationDefined : .transient
        }

        let root = PopoverView(settings: settings, store: store, controller: controller)
        popover.contentViewController = NSHostingController(rootView: root)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)

        KeyboardShortcuts.onKeyUp(for: .togglePopover) { [weak self] in
            self?.togglePopover(nil)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            show()
        }
    }

    private func show() {
        guard let button = statusItem.button else { return }
        store.refreshIfDiskChanged() // correctness baseline: fresh read on open
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Accessory apps must self-activate or text fields never receive keystrokes.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }
}
