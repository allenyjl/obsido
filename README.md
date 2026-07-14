# Obsido

A tiny macOS menu bar app for Obsidian-style markdown todo lists. Click the ☑︎ icon (or press your global hotkey) and your todo file opens in a popover: check things off, edit lines in place, add tasks — all written straight back to the plain markdown file in your vault.

Last updated: 2026-07-13

## Features

- **Per-line live preview** — the line you're editing shows raw markdown; every other line renders styled (headings, `==highlights==`, `[[wikilinks]]`, `#tags`, **bold**/*italic*).
- **Tappable checkboxes** — toggling writes exactly one character (`[ ]` ⇄ `[x]`) back to the file, atomically. Obsidian custom statuses (`[-]`, `[/]`, …) render but stay read-only.
- **Real editing** — click any line to edit, Enter commits and starts the next task, Backspace on an empty line deletes it, Esc cancels, drag to reorder, quick-add row at the bottom.
- **A few switchable files** — configure several markdown files; switch via the dropdown.
- **Plays nice with Obsidian** — file watcher picks up outside edits (surviving atomic saves); conflicting writes are dropped in favor of what's on disk; "Open in Obsidian" jumps to the note.
- **Menu bar niceties** — global hotkey, launch at login, pinnable popover.

Byte-preservation guarantee: parsing never rewrites your file. Frontmatter, tabs, CRLF, nesting, and custom statuses round-trip byte-identically (unit-tested).

## Requirements

- macOS 14+
- Xcode Command Line Tools (full Xcode not required)
- A local (non-synced) Obsidian vault is the supported setup

## Build & run

```sh
./scripts/check.sh          # build + tests + assemble build/Obsido.app
open build/Obsido.app
```

`./scripts/test.sh` runs the unit tests alone. The app is ad-hoc signed for personal use; see `docs/` for architecture and build-system notes.

## Status

Personal project, built for one user's workflow. Unofficial — not affiliated with Obsidian.
