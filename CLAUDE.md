@AGENTS.md

# Claude-specific notes

- Claude Code implements this project end to end (the owner chose this explicitly); no Codex handoff required, but keep `plan/active.md` current anyway so any tool can resume.
- Use plan mode for multi-file or architecturally uncertain changes.
- The live-preview editor is the highest-risk component — prototype focus/activation behavior (accessory apps need `NSApp.activate(ignoringOtherApps: true)` before TextFields accept keystrokes) before building on top of it.
- Before stopping mid-work, compacting, or ending a long session, update `plan/active.md`.
