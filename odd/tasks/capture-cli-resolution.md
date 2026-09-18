# Capture CLI resolution

## Objective
Allow Xcode-launched TTFXVideoCapture to locate the built Swift CLI without requiring a scheme argument.

## Problem and scope
The sibling executable assumption fails in Xcode DerivedData. Authorized scope: capture executable resolution, dependency preflight, regression tests and capture documentation. No automatic build, push or unrelated changes.

## Constraints
Strict TDD enabled by AGENTS.md. Runner: `swift test --filter CaptureExecutableResolutionTests`. Preserve explicit --swift-cli precedence; prefer executable sibling, otherwise repository .build/debug/ttfx. Validate dependencies before output creation. Existing artifacts may be stale; rebuild remains a user action.

## Tasks
- [x] C1 Add regression tests, observe RED, implement resolution/preflight and observe GREEN.
- [x] C2 Document resolution, build capture product, check diff and smoke-test missing dependencies without output creation.

## Acceptance and checks
Explicit invalid overrides fail without fallback. Missing/non-executable CLI has actionable guidance. Rust and ffmpeg paths are checked before capture. Run targeted tests, `swift build --product TTFXVideoCapture`, `git diff --check`.

## Delivery
One cohesive work-unit commit owned by parent. Forecast ~200 authored changed lines; strategy ask-on-risk. Rollback: resolver/preflight, tests and documentation together. Native review state and commit identity pending parent.

## Progress
Implementation and verification complete; commit/review identity pending parent.

- RED: `swift test --filter CaptureExecutableResolutionTests` failed compiling tests because resolveSwiftCLI/validateExecutable were absent. Initial sandbox cache failure was rerun with approved escalation.
- GREEN: same command passed 6 tests. Shared executable-file predicate is the refactored validation boundary.
- `swift test --filter TTFXComparisonTests`: passed 34 tests, including generated-video playback regressions.
- `swift build --product TTFXVideoCapture`: passed.
- `git diff --check`: passed.
- Runtime smoke: missing explicit Swift CLI, Rust, ffmpeg and valueless --swift-cli each exited 1 with actionable stderr, no Fatal error and no output directory created.
- Full Metal/media capture and interactive Xcode launch not performed. DerivedData lookup covered by fixture test. No automatic build/freshness detection; README explains rebuilding.
- Rollback: remove resolver/preflight/main error handling and associated tests/documentation together.
