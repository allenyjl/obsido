import Foundation
import ServiceManagement

/// User configuration persisted in UserDefaults (plain paths; app is unsandboxed).
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let filePaths = "filePaths"
        static let selectedPath = "selectedPath"
    }

    @Published var filePaths: [String] {
        didSet { UserDefaults.standard.set(filePaths, forKey: Keys.filePaths) }
    }

    @Published var selectedPath: String? {
        didSet { UserDefaults.standard.set(selectedPath, forKey: Keys.selectedPath) }
    }

    init() {
        filePaths = UserDefaults.standard.stringArray(forKey: Keys.filePaths) ?? []
        selectedPath = UserDefaults.standard.string(forKey: Keys.selectedPath)
        if selectedPath == nil || !filePaths.contains(selectedPath!) {
            selectedPath = filePaths.first
        }
    }

    func addFile(_ path: String) {
        guard !filePaths.contains(path) else {
            selectedPath = path
            return
        }
        filePaths.append(path)
        selectedPath = path
    }

    func removeFile(_ path: String) {
        filePaths.removeAll { $0 == path }
        if selectedPath == path {
            selectedPath = filePaths.first
        }
    }

    static func displayName(for path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login change failed: \(error)")
        }
        objectWillChange.send()
    }
}
