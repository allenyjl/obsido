import Testing
@testable import Obsido

@Suite struct RoundTripTests {
    static let fixtures: [String] = [
        "",
        "- [ ] one task",
        "- [ ] task, no trailing newline",
        "- [x] done\n",
        "# Heading\n\n- [ ] a\n- [x] b\n",
        "---\ncreated: 2026-07-13\ntags: [todo]\n---\n\n# Today\n\n- [ ] alpha\n\t- [x] nested tab\n    - [-] custom status\n* [ ] star marker\n+ [X] plus marker\n1. [ ] ordered\n\nplain paragraph ==highlight== [[wikilink]] #tag\n",
        "line one\r\nline two\r\n- [ ] crlf task\r\n",
        "\n\n\n",
        "- [ ]\n",
        "-[ ] not a task (no space after dash)\n- [xx] not a task (two chars)\n",
    ]

    @Test(arguments: fixtures)
    func parseSerializeIsByteIdentical(_ text: String) {
        let doc = TodoDocument(text: text)
        #expect(doc.text == text)
    }
}

@Suite struct ClassificationTests {
    private func kinds(_ text: String) -> [TodoDocument.Kind] {
        TodoDocument(text: text).lines.map(\.kind)
    }

    @Test func detectsTaskMarkers() {
        for raw in ["- [ ] a", "* [ ] a", "+ [ ] a", "1. [ ] a", "12) [ ] a", "  - [ ] indented", "\t- [ ] tab"] {
            guard case .task = kinds(raw)[0] else {
                Issue.record("expected task for \(raw)")
                return
            }
        }
    }

    @Test func rejectsNonTasks() {
        for raw in ["-[ ] a", "- [xx] a", "- [] a", "[ ] a", "-- [ ] a", "plain text"] {
            if case .task = kinds(raw)[0] {
                Issue.record("expected non-task for \(raw)")
            }
        }
    }

    @Test func taskFields() {
        let doc = TodoDocument(text: "  - [x] Buy milk")
        guard case .task(let info) = doc.lines[0].kind else {
            Issue.record("not a task")
            return
        }
        #expect(info.isChecked)
        #expect(info.isToggleable)
        #expect(info.text == "Buy milk")
    }

    @Test func emptyTaskText() {
        let doc = TodoDocument(text: "- [ ]")
        guard case .task(let info) = doc.lines[0].kind else {
            Issue.record("not a task")
            return
        }
        #expect(info.text.isEmpty)
        #expect(!info.isChecked)
    }

    @Test func customStatusIsTaskButNotToggleable() {
        for raw in ["- [-] cancelled", "- [/] partial", "- [>] forwarded"] {
            let doc = TodoDocument(text: raw)
            guard case .task(let info) = doc.lines[0].kind else {
                Issue.record("expected task for \(raw)")
                continue
            }
            #expect(!info.isToggleable, "custom status should not be toggleable: \(raw)")
        }
    }

    @Test func uppercaseXIsCheckedAndToggleable() {
        let doc = TodoDocument(text: "- [X] shouting done")
        guard case .task(let info) = doc.lines[0].kind else {
            Issue.record("not a task")
            return
        }
        #expect(info.isChecked)
        #expect(info.isToggleable)
    }

    @Test func headingLevels() {
        let doc = TodoDocument(text: "# One\n### Three\n####### seven hashes is not a heading")
        guard case .heading(let l1) = doc.lines[0].kind, case .heading(let l3) = doc.lines[1].kind else {
            Issue.record("headings not detected")
            return
        }
        #expect(l1 == 1)
        #expect(l3 == 3)
        if case .heading = doc.lines[2].kind {
            Issue.record("7 hashes must not be a heading")
        }
    }

    @Test func blankLines() {
        let doc = TodoDocument(text: "a\n\n   \nb")
        #expect(doc.lines[1].kind == .blank)
        #expect(doc.lines[2].kind == .blank)
        #expect(doc.lines[0].kind == .other)
    }

    @Test func frontmatterOnlyAtStart() {
        let doc = TodoDocument(text: "---\nkey: value\n---\nbody\n---\nnot frontmatter\n")
        #expect(doc.lines[0].kind == .frontmatter)
        #expect(doc.lines[1].kind == .frontmatter)
        #expect(doc.lines[2].kind == .frontmatter)
        #expect(doc.lines[3].kind == .other)
        #expect(doc.lines[4].kind != .frontmatter)
    }

    @Test func crlfTaskStillDetected() {
        let doc = TodoDocument(text: "- [ ] windows line\r\n")
        guard case .task = doc.lines[0].kind else {
            Issue.record("CRLF task not detected")
            return
        }
    }
}

@Suite struct ToggleTests {
    @Test func toggleFlipsExactlyOneCharacter() {
        let original = "# H\n- [ ] alpha\n- [x] beta\n"
        var doc = TodoDocument(text: original)
        #expect(doc.toggleTask(at: 1))
        #expect(doc.text == "# H\n- [x] alpha\n- [x] beta\n")
        #expect(doc.toggleTask(at: 2))
        #expect(doc.text == "# H\n- [x] alpha\n- [ ] beta\n")
    }

    @Test func togglePreservesIndentAndCRLF() {
        var doc = TodoDocument(text: "\t  - [ ] deep\r\n")
        #expect(doc.toggleTask(at: 0))
        #expect(doc.text == "\t  - [x] deep\r\n")
    }

    @Test func toggleUppercaseXBecomesUnchecked() {
        var doc = TodoDocument(text: "- [X] a")
        #expect(doc.toggleTask(at: 0))
        #expect(doc.text == "- [ ] a")
    }

    @Test func toggleRefusesCustomStatusAndNonTasks() {
        let original = "- [-] custom\nplain\n"
        var doc = TodoDocument(text: original)
        #expect(!doc.toggleTask(at: 0))
        #expect(!doc.toggleTask(at: 1))
        #expect(doc.text == original)
    }
}

@Suite struct MutationTests {
    @Test func replaceLine() {
        var doc = TodoDocument(text: "- [ ] old\n")
        doc.replaceLine(at: 0, with: "- [ ] new")
        #expect(doc.text == "- [ ] new\n")
        guard case .task(let info) = doc.lines[0].kind else {
            Issue.record("reclassification failed")
            return
        }
        #expect(info.text == "new")
    }

    @Test func insertLine() {
        var doc = TodoDocument(text: "a\nb\n")
        doc.insertLine("- [ ] between", at: 1)
        #expect(doc.text == "a\n- [ ] between\nb\n")
    }

    @Test func removeLine() {
        var doc = TodoDocument(text: "a\nb\nc")
        doc.removeLine(at: 1)
        #expect(doc.text == "a\nc")
    }

    @Test func moveLine() {
        var doc = TodoDocument(text: "1\n2\n3\n")
        doc.moveLine(from: 0, to: 2)
        #expect(doc.text == "2\n3\n1\n")
    }

    @Test func lineIdentityIsStableAcrossToggle() {
        var doc = TodoDocument(text: "- [ ] a\n- [ ] b\n")
        let idBefore = doc.lines[0].id
        _ = doc.toggleTask(at: 0)
        #expect(doc.lines[0].id == idBefore)
    }
}
