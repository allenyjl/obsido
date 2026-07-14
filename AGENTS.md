# Obsido — agent instructions

Last updated: 2026-07-13

## Project summary

Obsido is a personal macOS menu bar app. Clicking its status-bar icon opens a popover that shows one of a few user-configured Obsidian markdown files (simple todo lists) with per-line live-preview editing: the focused line shows raw markdown, all other lines render styled; checkboxes are tappable and write back to the file. The vault is local-only (no sync service).

Note: the folder may still be named `Obsidian_Todo_list_toolbar`; the project/app name is **Obsido** (repo name `obsido`).

## Stack

- Swift / SwiftUI, macOS 14+ target, `MenuBarExtra` with `.window` style, `LSUIElement = YES`, **not sandboxed**.
- Dependencies (SPM): `apple/swift-markdown` (parsing), `sindresorhus/KeyboardShortcuts` (global hotkey), `orchetect/MenuBarExtraAccess` (pin / programmatic dismissal). Do not add others without stating why.
- Project generated with XcodeGen from `project.yml`; build with `xcodebuild`.

## Commands

- `./scripts/check.sh` — full verification: regenerate project, build, run unit tests.
- `./scripts/test.sh` — unit tests only.
- Until those exist, see `plan/specs/obsido-v1.md` for the intended build steps.

## Layout

- `Sources/` — app code. `Tests/` — unit tests.
- `docs/` — durable truth about the current system (more authoritative than `plan/`).
- `plan/` — intent and active work. `plan/specs/obsido-v1.md` is the v1 spec; `plan/active.md` is the handoff file.

## Rules

- File writes to the user's markdown files must be atomic (`Data.write(options: .atomic)`) and minimal: checkbox toggles edit only the bracket character of one line; text edits replace only committed lines. Never round-trip the whole document through a parser to save (it destroys frontmatter/formatting).
- Only ever write `' '` / `'x'` checkbox states; render Obsidian custom statuses (`[-]`, `[/]`, …) read-only.
- Core markdown logic (line model, toggle, serialization) must be unit-tested; round-trip parse→serialize of a file with frontmatter, tabs, and nested lists must be byte-identical.
- Do not commit user file paths, vault contents, or secrets.
- Keep diffs focused; no formatting sweeps or dependency migrations unless asked.

## Definition of done

Code builds via `./scripts/check.sh` with zero warnings-as-errors regressions, unit tests pass, and behavior claims are backed by command output (or an explicit note of what was only manually verified).
