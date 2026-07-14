---
created: 2026-07-13
updated: 2026-07-13
---

# Active work

## Status

Active

## Current task

Obsido v1 — implemented (M0–M6). Awaiting owner's hands-on feedback.

## State

- **Complete:** all seven milestones. Menu bar app with per-line live-preview editor, tappable checkboxes with single-character write-back, quick-add row (top of popover, inserts under the first heading), multi-file dropdown, settings page (file list, launch at login, hotkey recorder), pin, Open in Obsidian, file watcher surviving atomic saves, conflict-checked atomic writes. 37 unit tests green. Built and running on the owner's machine.
- **Build system deviation from spec:** pure SPM + `scripts/bundle.sh` instead of XcodeGen/xcodebuild (no Xcode on machine) — see `docs/decisions/0001-spm-clt-build.md`.
- **Post-v1 fix (2026-07-13):** owner reported clicking a line did nothing. Root cause: rows lived in a SwiftUI `List`; on macOS, swapping row content + programmatic `@FocusState` inside List's NSTableView cells silently fails. Editor now uses ScrollView/LazyVStack with explicit `editingID` state and one-runloop-deferred focus. **Drag-reorder was dropped with `List.onMove`** (was the pre-flagged flakiest interaction; re-add via custom drag if missed). Quick-add now inserts at the top of the list (`TodoDocument.firstTaskInsertionIndex()` — after frontmatter + first leading heading) instead of appending.
- **Commands run:** `./scripts/check.sh` green (build + 37 tests + bundle). Runtime smoke-tested: app survives demo-file load, external in-place edit, and atomic replace with watcher re-arm.
- **Verified only manually/partially:** visual appearance and click/keyboard interactions (Enter/Esc/Backspace flows, click-to-edit focus) — no UI-automation tooling in the build environment. Owner is verifying hands-on.

## Known risks / watch items

- Click-to-edit after the List→ScrollView rewrite is pending owner confirmation.
- `settings.selectedPath` Picker binding uses `String?` tags — verify switching works with 2+ files configured.

## Next recommended step

Owner tries the app (add a real vault file in Settings). File issues from real use; then tag v0.1.0.
