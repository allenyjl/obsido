import SwiftUI

/// The per-line live-preview editor: the focused line is a raw-markdown text
/// field; every other line renders styled. Checkboxes toggle without entering
/// edit mode.
///
/// Rows live in a ScrollView/LazyVStack, NOT a List: on macOS, swapping row
/// content and driving @FocusState inside List's NSTableView-backed cells
/// silently breaks (clicking a line did nothing) — plain stacks are reliable.
struct TodoListView: View {
    @ObservedObject var store: DocumentStore
    /// Which line renders as a raw editor. Focus follows one runloop later —
    /// setting @FocusState toward a field created in the same update is flaky.
    @State private var editingID: UUID?
    @FocusState private var focusedID: UUID?
    @State private var newTaskText = ""
    @FocusState private var newTaskFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let document = store.document {
                addTaskRow
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(document.lines) { line in
                            LineRow(
                                line: line,
                                isEditing: editingID == line.id,
                                store: store,
                                editingID: $editingID,
                                focusedID: $focusedID
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Click in empty space below the lines: commit any edit.
                    focusedID = nil
                    editingID = nil
                }
            }
        }
    }

    private var addTaskRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            TextField("Add a task…", text: $newTaskText)
                .textFieldStyle(.plain)
                .focused($newTaskFocused)
                .onSubmit {
                    let text = newTaskText.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    store.addTaskToTop(text: text)
                    newTaskText = ""
                    newTaskFocused = true // keep focus for rapid entry
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// One line of the document.
private struct LineRow: View {
    let line: TodoDocument.Line
    let isEditing: Bool
    let store: DocumentStore
    @Binding var editingID: UUID?
    var focusedID: FocusState<UUID?>.Binding

    @State private var draft = ""
    @State private var isHovering = false

    var body: some View {
        Group {
            if isEditing {
                rawEditor
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    rendered
                    if isDeletable {
                        deleteButton
                            .opacity(isHovering ? 1 : 0)
                    }
                }
                .onHover { isHovering = $0 }
            }
        }
    }

    /// Frontmatter lines can't be deleted one-by-one — a half-deleted YAML
    /// block corrupts the file header. Everything else can.
    private var isDeletable: Bool {
        line.kind != .frontmatter
    }

    private var deleteButton: some View {
        Button {
            deleteLine(handingFocusBack: false)
        } label: {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Delete line")
    }

    private func deleteLine(handingFocusBack: Bool) {
        let previous = store.remove(id: line.id)
        guard handingFocusBack else { return }
        editingID = previous
        if let previous {
            Task { @MainActor in focusedID.wrappedValue = previous }
        }
    }

    // MARK: - Raw editing mode

    private var rawEditor: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .focused(focusedID, equals: line.id)
            .onAppear { draft = line.raw }
            .onSubmit { commitAndAddBelow() }
            .onExitCommand {
                draft = line.raw // discard edit
                stopEditing(commit: false)
            }
            .onKeyPress(.delete, phases: .down) { press in
                // ⌘Delete kills the whole line; plain Backspace only once empty.
                guard press.modifiers.contains(.command) || draft.isEmpty else { return .ignored }
                deleteLine(handingFocusBack: true)
                return .handled
            }
            .onChange(of: focusedID.wrappedValue) { _, newValue in
                // Focus moved elsewhere (another line, add-row, or nil): commit.
                if newValue != line.id, isEditing {
                    stopEditing(commit: true)
                }
            }
    }

    private func stopEditing(commit: Bool) {
        if commit {
            store.commit(id: line.id, raw: draft)
        }
        if editingID == line.id {
            editingID = nil
        }
        if focusedID.wrappedValue == line.id {
            focusedID.wrappedValue = nil
        }
    }

    private func commitAndAddBelow() {
        // A new task line inherits the indent of the committed task line.
        let newRaw: String
        if case .task = TodoDocument(text: draft).lines.first?.kind {
            let indent = draft.prefix { $0 == " " || $0 == "\t" }
            newRaw = "\(indent)- [ ] "
        } else {
            newRaw = ""
        }
        let newID = store.commitAndInsertBelow(id: line.id, draft: draft, newRaw: newRaw)
        editingID = newID
        if let newID {
            Task { @MainActor in focusedID.wrappedValue = newID }
        }
    }

    // MARK: - Rendered mode

    @ViewBuilder
    private var rendered: some View {
        switch line.kind {
        case .task(let info):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                checkbox(info)
                renderedText(MarkdownStyler.styledInline(info.text, checked: info.isChecked))
            }
            .padding(.leading, indentWidth)
        case .heading(let level):
            renderedText(MarkdownStyler.styledHeading(headingText, level: level))
                .padding(.top, 4)
        case .blank:
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 8)
                .contentShape(Rectangle())
                .onTapGesture { focus() }
        case .frontmatter:
            Text(line.raw)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { focus() }
        case .other:
            renderedText(MarkdownStyler.styledInline(line.raw))
                .padding(.leading, indentWidth)
        }
    }

    private func renderedText(_ attributed: AttributedString) -> some View {
        Text(attributed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { focus() }
    }

    private func checkbox(_ info: TodoDocument.TaskInfo) -> some View {
        Button {
            if info.isToggleable {
                store.toggle(id: line.id)
            }
        } label: {
            Image(systemName: checkboxSymbol(info))
                .foregroundStyle(info.isChecked ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!info.isToggleable)
    }

    private func checkboxSymbol(_ info: TodoDocument.TaskInfo) -> String {
        if info.isToggleable {
            return info.isChecked ? "checkmark.square.fill" : "square"
        }
        return "square.slash" // Obsidian custom status: shown, not editable
    }

    private func focus() {
        draft = line.raw
        editingID = line.id
        // Defer focus one runloop so the TextField exists when focus lands.
        Task { @MainActor in focusedID.wrappedValue = line.id }
    }

    private var indentWidth: CGFloat {
        let prefix = line.raw.prefix { $0 == " " || $0 == "\t" }
        let units = prefix.reduce(0.0) { $0 + ($1 == "\t" ? 1.0 : 0.25) }
        return CGFloat(units) * 16
    }

    private var headingText: String {
        let content = line.raw.hasSuffix("\r") ? String(line.raw.dropLast()) : line.raw
        return String(content.drop(while: { $0 == "#" }).drop(while: { $0 == " " }))
    }
}
