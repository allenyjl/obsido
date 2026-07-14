---
created: 2026-07-13
updated: 2026-07-13
---

# Decision: SPM + bundling script instead of XcodeGen/xcodebuild

## Status

Accepted

## Context

The v1 spec planned XcodeGen + `xcodebuild`. This machine has only Command Line Tools (no Xcode), and `xcodebuild` requires full Xcode (~12 GB download).

## Decision

Build with pure Swift Package Manager and assemble the `.app` bundle by hand:

- `Package.swift` executable target; `scripts/bundle.sh` copies the binary + `Support/Info.plist` into `build/Obsido.app` and ad-hoc signs it.
- `scripts/test.sh` passes `-F`/`-rpath` flags for the CLT's Swift Testing framework (`/Library/Developer/CommandLineTools/Library/Developer/Frameworks` and `.../usr/lib`), which SPM does not add on its own without Xcode.
- KeyboardShortcuts is pinned to `1.10.0`: newer versions contain `#Preview` macros, which need Xcode's previews macro plugin and fail to compile under CLT.

## Consequences

- Anyone (or any agent) building this repo needs no Xcode; `./scripts/check.sh` is the whole story.
- No Xcode project exists; editing in Xcode means opening `Package.swift` directly (works, previews don't).
- Upgrading KeyboardShortcuts past 1.10.0 requires either installing Xcode or the upstream guarding its previews.

## Incident note (this machine)

The preinstalled CLT was stale (Swift 6.0.2 on macOS 26.5) with a broken SPM. Fixed by installing CLT 26.6 via `softwareupdate` (surface the packages by `touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress`) — after which two leftover `private.swiftinterface` files from the old CLT shadowed the new PackageDescription module and had to be deleted manually (`sudo rm .../ManifestAPI/PackageDescription.swiftmodule/*private.swiftinterface`). Symptom to recognize: manifest link errors about `Package.__allocating_init` with `swiftLanguageVersions: [SwiftVersion]?` in the signature.
