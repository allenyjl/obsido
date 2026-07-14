import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }

            GroupBox("Files") {
                VStack(alignment: .leading, spacing: 4) {
                    if settings.filePaths.isEmpty {
                        Text("No files yet — add a markdown file from your vault.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .padding(.vertical, 4)
                    }
                    ForEach(settings.filePaths, id: \.self) { path in
                        HStack {
                            Text(AppSettings.displayName(for: path))
                            Text(path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                settings.removeFile(path)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        pickFile()
                    } label: {
                        Label("Add file…", systemImage: "plus")
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    HStack {
                        Text("Toggle popover:")
                        KeyboardShortcuts.Recorder(for: .togglePopover)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Spacer()
        }
        .padding(12)
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.addFile(url.path)
        }
    }
}

extension KeyboardShortcuts.Name {
    // KeyboardShortcuts 1.10 predates Sendable annotations; Name is immutable in practice.
    nonisolated(unsafe) static let togglePopover = Self("togglePopover")
}
