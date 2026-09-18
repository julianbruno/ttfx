# Beginner platform guide

## Outcome
Document a beginner path for macOS native Swift, Ubuntu Rust, and Windows using Ubuntu in WSL. Clearly distinguish available products from pending native Swift portability.

## Scope and constraints
Documentation only: docs/getting-started-platforms.md, README.md, docs/swift-port/README.md, and this ledger. English artifacts. No installs, source changes, remote execution, push, or merge. TDD always applies to behavior; prose uses structural checks, not invented RED. Delivery: ask-on-risk; forecast approximately 200 authored lines, one documentation work unit. Parent owns commit.

## Tasks
- [x] T01: Write beginner setup/use guide with platform/product and evidence boundaries.
- [x] T02: Link guide from both READMEs; validate local links, shell syntax, examples, and diff.

## Acceptance and checks
Explicit command shells, expected result, repeat-use instructions, trusted official installer sources, and troubleshooting. Verify prerequisites against official Rust/Apple/Microsoft documentation and repository CLI/platform configuration. Check shell blocks with bash -n without executing installers; local binaries may run help/small print smoke. Ubuntu/WSL setup cannot be verified on current macOS host.

## Progress
Exploration: Cargo Rust CI includes Ubuntu/macOS; Swift package CI configures Linux CLI build/help but its full cross-platform CLI spec remains pending. Package declares macOS 14/iOS 17, Swift tools 6.2. Native Windows Rust is not the documented product route. Existing local Rust/Swift binary help runs succeed.

## Verification evidence
- Official Rust installation/book, Swift macOS install, Apple command-line tools, and Microsoft WSL installation/environment pages consulted on 2026-09-17. Apple technote fallback was unavailable; official Rust book independently supplies xcode-select and Ubuntu linker prerequisites.
- bash -n: all 10 shell blocks passed (syntax only, no installers/builds run).
- 114 local file link targets across guide/both READMEs exist; referenced gallery heading verified structurally.
- Existing macOS binaries: Rust and Swift --help, print --help, small print, and print --print-speed 5: 8 subprocesses exited 0 with nonempty output. Small print output Rust 10497 bytes, Swift 10173 bytes; effect-speed print Rust 9673 bytes, Swift 9370 bytes. These are execution smoke checks, not parity or fresh-build proof.
- git diff --check passed. No Ubuntu/WSL setup or native Windows checks performed. TDD RED/GREEN N/A: passive documentation, no behavioral source changes. PowerShell WSL command verified against Microsoft's documented invocation, not executed.
- RDD remains off per parent; passive structural readback. Rollback boundary: remove new guide and two README links together; source/media unchanged.

## Next step
Parent structural readback and one conventional documentation work-unit commit; record commit identity here. Both completed tasks await that commit closure. No push/merge authorized.
