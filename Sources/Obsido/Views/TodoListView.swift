import SwiftUI

/// The per-line live-preview editor: the focused line is a raw-markdown text
/// field; every other line renders styled. Checkboxes toggle without entering
/// edit mode.
struct TodoListView: View {
    @ObservedObject var store: DocumentStore
    @FocusState private var focusedLine: UUID?
    @State private var newTaskText = ""
    @FocusState private var newTaskFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let document = store.document {
                List {
                    ForEach(document.lines) { line in
                        LineRow(
                            line: line,
                            isFocused: focusedLine == line.id,
                            store: store,
                            focusedLine: $focusedLine
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    }
                    .onMove { source, destination in
                        store.move(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Divider()
                addTaskRow
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
                    store.appendTask(text: text)
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
    let isFocused: Bool
    let store: DocumentStore
    var focusedLine: FocusState<UUID?>.Binding

    @State private var draft = ""

    var body: some View {
        Group {
            if isFocused {
                rawEditor
            } else {
                rendered
            }
        }
    }

    // MARK: - Raw editing mode

    private var rawEditor: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .focused(focusedLine, equals: line.id)
            .onAppear { draft = line.raw }
            .onSubmit { commitAndAddBelow() }
            .onExitCommand {
                draft = line.raw // discard edit
                focusedLine.wrappedValue = nil
            }
            .onKeyPress(.delete, phases: .down) { _ in
                guard draft.isEmpty else { return .ignored }
                focusedLine.wrappedValue = store.remove(id: line.id)
                return .handled
            }
            .onChange(of: focusedLine.wrappedValue) { _, newValue in
                // Focus moved elsewhere: commit whatever was typed.
                if newValue != line.id {
                    store.commit(id: line.id, raw: draft)
                }
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
        focusedLine.wrappedValue = store.commitAndInsertBelow(id: line.id, draft: draft, newRaw: newRaw)
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
                .frame(height: 8)
                .contentShape(Rectangle())
                .onTapGesture { focus() }
        case .frontmatter:
            Text(line.raw)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
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
        focusedLine.wrappedValue = line.id
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
