import SwiftUI

/// Coordinates popover-level behavior owned by the AppDelegate (pinning).
@MainActor
final class PopoverController: ObservableObject {
    @Published var isPinned = false {
        didSet { applyPin?(isPinned) }
    }
    var applyPin: ((Bool) -> Void)?
}

struct PopoverView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: DocumentStore
    @ObservedObject var controller: PopoverController
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showingSettings {
                SettingsView(settings: settings) {
                    showingSettings = false
                }
            } else {
                header
                Divider()
                content
                Divider()
                footer
            }
        }
        .frame(width: 360, height: 480)
        .onChange(of: settings.selectedPath) { _, newValue in
            store.open(path: newValue)
        }
    }

    private var header: some View {
        HStack {
            if settings.filePaths.isEmpty {
                Text("Obsido")
                    .font(.headline)
            } else {
                Picker("", selection: $settings.selectedPath) {
                    ForEach(settings.filePaths, id: \.self) { path in
                        Text(AppSettings.displayName(for: path))
                            .tag(String?.some(path))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            }
            Spacer()
            Button {
                controller.isPinned.toggle()
            } label: {
                Image(systemName: controller.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .foregroundStyle(controller.isPinned ? Color.accentColor : Color.secondary)
            .help("Keep the popover open while clicking elsewhere")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loaded:
            TodoListView(store: store)
        case .noFile:
            emptyState(
                symbol: "doc.badge.plus",
                title: "No file configured",
                message: "Add a markdown todo file from your vault in Settings."
            )
        case .missing(let path):
            emptyState(
                symbol: "questionmark.folder",
                title: "File not found",
                message: path
            )
        }
    }

    private func emptyState(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .truncationMode(.middle)
            Button("Open Settings") { showingSettings = true }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                store.openInObsidian()
            } label: {
                Label("Open in Obsidian", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(settings.selectedPath == nil)

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit Obsido")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
