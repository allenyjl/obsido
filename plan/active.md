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

- **Complete:** all seven milestones. Menu bar app with per-line live-preview editor, tappable checkboxes with single-character write-back, quick-add row, drag reorder, multi-file dropdown, settings page (file list, launch at login, hotkey recorder), pin, Open in Obsidian, file watcher surviving atomic saves, conflict-checked atomic writes. 29 unit tests green. Built and running on the owner's machine.
- **Build system deviation from spec:** pure SPM + `scripts/bundle.sh` instead of XcodeGen/xcodebuild (no Xcode on machine) — see `docs/decisions/0001-spm-clt-build.md`.
- **Commands run:** `./scripts/check.sh` green (build + 29 tests + bundle). Runtime smoke-tested: app survives demo-file load, external in-place edit, and atomic replace with watcher re-arm.
- **Verified only manually/partially:** visual appearance, click/keyboard interactions (Enter/Esc/Backspace flows, drag reorder, focus behavior in the accessory popover) — no UI-automation tooling available in the build environment (no Screen Recording permission, no Xcode UI tests). Owner should exercise these.

## Known risks / watch items

- TextField focus in the accessory-app popover: `NSApp.activate` + `makeKey` are called on show, but first-click focus quirks are possible — the top pre-identified risk, unverifiable without hands-on use.
- Drag-reorder via SwiftUI `List.onMove` in an NSPopover is the flakiest interaction; ship-acceptable to drop if it misbehaves.
- `settings.selectedPath` Picker binding uses `String?` tags — verify switching works with 2+ files configured.

## Next recommended step

Owner tries the app (add a real vault file in Settings). File issues from real use; then tag v0.1.0.
