---
created: 2026-07-13
updated: 2026-07-13
---

# Obsido v1 spec

## Status

Implemented — 2026-07-13. Build system deviates from this spec (pure SPM instead of XcodeGen/xcodebuild; KeyboardShortcuts pinned 1.10.0; no swift-markdown dependency — regex classification proved sufficient): see `docs/decisions/0001-spm-clt-build.md`. App shell is NSStatusItem+NSPopover (the spec's named fallback) rather than MenuBarExtra, chosen up front for programmatic open/close, trivial pinning, and focus control.

## Purpose

Define v1 of Obsido: a macOS menu bar app that opens a popover showing one of a few user-configured Obsidian markdown todo files, with live-preview editing and safe write-back. This spec is the implementation source of truth; research backing these choices is in `docs/research/menubar-research-2026-07-13.md`.

## Product decisions (owner-confirmed)

| Decision | Choice |
|---|---|
| Interaction | Full editing in the popover |
| Edit engine | Live preview, **per-line**: focused line shows raw markdown, other lines render styled |
| Files | A few switchable files (ordered list), dropdown switcher at top of popover |
| Click UX | Anchored popover (MenuBarExtra `.window`), pinnable |
| Menu bar icon | Static SF Symbol only (no count/badge) |
| Sync environment | Local-only vault — no iCloud/Obsidian Sync handling needed beyond atomic writes |
| Niceties in v1 | Launch at login, global hotkey, "Open in Obsidian" button, pin popover |
| Stack | Native Swift/SwiftUI; owner prioritizes a functional app over learning value |
| Distribution | Personal use; built locally; no notarization/App Store |

## Architecture

### App shell
- SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)`, fixed frame ≈ 360×480 (avoids the known ScrollView height-collapse bug on second open).
- `LSUIElement = YES` (no Dock icon). Never call `setActivationPolicy` in `App.init()` (NSApp is nil → crash).
- Quit button inside the popover footer.
- Pin: `MenuBarExtraAccess` for programmatic open/close; when pinned, keep the window open on outside clicks.
- Focus gotcha: activate the app (`NSApp.activate(ignoringOtherApps: true)`) when the popover opens so text editing receives keystrokes.

### Document model (core, unit-tested, UI-free)
- `TodoDocument`: ordered array of `Line` values, each retaining its **exact raw text**. Parse with `apple/swift-markdown` (or line-level regex where simpler) only to *classify* lines (task / heading / blank / other) and extract checkbox state + indent; never to regenerate text.
- Serialization = join raw lines. Round-trip of any file (frontmatter, tabs, nested lists, custom statuses) must be byte-identical.
- Checkbox toggle = replace the single bracket character in that line's raw text.

### Editor (per-line live preview)
- List of rows; each row has two modes:
  - **Rendered** (unfocused): styled AttributedString — headings sized, task rows show a tappable checkbox + styled text (strikethrough when done), Obsidian extras (wikilinks `[[x]]`, `==highlights==`, `#tags`) styled via regex preprocessing; frontmatter block collapsed/dimmed.
  - **Raw** (focused): a TextField containing the line's exact raw markdown.
- Editing behaviors: click text to focus (raw mode); Enter commits and inserts a new line below (pre-filled `- [ ] ` if current line is a task); Backspace on empty line deletes it; Esc cancels the line edit; drag handle to reorder lines; trailing "Add a task…" row appends.
- Checkbox tap works without entering edit mode and writes back immediately.
- Only `[ ]`/`[x]` are toggleable; custom statuses (`[-]`, `[/]`, …) render read-only.

### Persistence & safety
- Reads: re-read the file on every popover open (correctness baseline) + `DispatchSource.makeFileSystemObjectSource` watcher (`O_EVTONLY`; mask write/extend/delete/rename; **re-arm on delete/rename** to survive atomic saves; debounce ~200 ms) for live refresh while open/pinned.
- Writes: immediate per-mutation (toggle, line commit, insert, delete, reorder) — never batched. Before writing, verify the file's mtime/content matches the last read; on mismatch, reload and re-render instead of writing (local-only vault makes real conflicts rare). Write with `Data.write(options: .atomic)`. Expect our own atomic write to trip the watcher (new inode) — re-arm and ignore the self-change.
- If the file is deleted/renamed externally: show a "file missing" state with a re-pick button.

### Settings
- Files: add (NSOpenPanel, `.md`), remove, reorder; display name = filename sans extension.
- Toggles: launch at login (`SMAppService.mainApp`), global hotkey recorder (`KeyboardShortcuts`).
- Storage: UserDefaults (plain paths — app is unsandboxed). Settings shown in a sheet/inline within the popover to avoid the accessory-app Settings-window activation dance.

### Obsidian integration
- "Open in Obsidian" footer button: `NSWorkspace.shared.open` on `obsidian://open?path=<url-encoded absolute path>` (resolves vault automatically; no vault-name config).
- No plugins required; Obsidian re-indexes external file changes on its own.

## Build system

- XcodeGen `project.yml` → `xcodebuild` (install via `brew install xcodegen` if missing). App target `Obsido` + unit-test target `ObsidoTests`.
- `scripts/check.sh`: xcodegen + build + tests. `scripts/test.sh`: tests only.
- Signing: local automatic (Personal Team ok); no notarization.

## Milestones

1. **M0 Scaffold** — repo structure, project.yml, empty MenuBarExtra popover with icon + Quit; builds and shows in menu bar.
2. **M1 Read & render** — file config (single file first), TodoDocument model + tests, rendered read-only view with checkboxes displayed.
3. **M2 Toggle write-back** — tappable checkboxes, single-line surgery, atomic write, watcher with re-arm, refresh-on-open.
4. **M3 Editing** — per-line raw/rendered switching, Enter/Backspace/Esc behaviors, add row, drag reorder, conflict check on write.
5. **M4 Multi-file** — file list in settings, dropdown switcher.
6. **M5 Niceties** — launch at login, global hotkey, Open in Obsidian, pin.
7. **M6 Polish & verify** — empty/missing-file states, dark mode pass, full manual checklist, README.

## Verification

- `./scripts/check.sh` green at every milestone.
- Unit tests: parse/serialize byte-identical round-trips (frontmatter, tabs, nested, custom statuses, CRLF), toggle correctness, line insert/delete/reorder serialization.
- Manual checklist (M6): edit in Obsidian while popover open → popover updates; toggle in Obsido → Obsidian updates within ~2 s; atomic-save editors (save via rename) don't kill the watcher; hotkey opens popover with keyboard focus working; survives logout/login with launch-at-login.

## Risks

- **Editor focus/activation** in an accessory app is the top risk — prototype first (M3 spike).
- MenuBarExtra `.window` quirks (no first-party programmatic dismissal, macOS 14→15 behavior changes) — MenuBarExtraAccess mitigates; fall back to NSStatusItem+NSPopover only if blocked.
- Drag-reorder inside a SwiftUI List in a menu bar window can be finicky; acceptable to ship M3 without reorder and add it in M6 if it fights back.

## Out of scope for v1

Menu bar count/badge, daily-note date patterns, sync-service conflict handling, Obsidian Tasks plugin metadata (due dates, recurrence), multi-vault awareness, App Store distribution.
