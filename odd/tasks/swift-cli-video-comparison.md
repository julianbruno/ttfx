# Swift CLI video comparison track

## Outcome and scope
Add actual pure-Swift executable ANSI output as a fourth independently hideable track in TTFX Video Comparison. Capture the executable, not relabeled SwiftUI/Metal frames. Preserve legacy two/three-track libraries and existing renderers. CLI source/dependency portability work remains separate and pending.

## Decisions and checks
- User authorized implementation; technical artifacts English.
- Strict TDD explicitly enabled: observed RED then GREEN/REFACTOR; swift test.
- RDD off globally; no native review. Local commits authorized by ODD; user subsequently authorized local merge to master. No push/PR/remote operations.
- Branch codex/cross-platform-cli; starting checkpoint c3d221e. Rust reference 0f24d88408c8b815761c2c07da7dc9b411f63016.
- Delivery ask-on-risk with user-selected stacked-to-main; two coherent local slices if required. Forecast 300–450 authored changed lines, generated videos excluded. Never compress code to fit budget.
- Video recording is macOS-only artifact tooling; CLI remains GUI-free. No claim of Windows/Linux certification.

## Tasks
- [x] V01: Capture real Swift CLI --parity-dump output with shared Rust/CLI arguments; store frames/video and optional swiftCLI manifest metadata/provenance. Legacy decode and track validation regression tests; CLI subprocess behavior/cap tests; setup docs and capture script build.
- [x] V02: Fourth synchronized player and independently hideable Swift CLI pane; missing-recording notice for older libraries. Load/clear/readiness/play/pause/seek regression tests. Generate all 37 effect libraries with the added track and verify metadata/decoding/frame counts; report failures without claiming animation parity.

## Verification
Required: swift test --filter TTFXComparisonTests; swift test --filter TTFXCLITests; swift build --product ttfx; swift build --product TTFXComparisonApp; bash -n tools/video-comparison/capture.sh. Runtime: first single-effect print capture then all-effect capture, ffprobe frame/dimension/fps and full decode, generated-library player integration. App launch smoke when supported. Each task includes tests/docs and one conventional work-unit commit, exact focused/runtime proof and rollback boundaries.

## Progress and slices
V01 observed RED: swift test --filter TTFXComparisonTests failed compilation for missing swiftCLI/ansiDump/dumpArguments. GREEN: 17 comparison tests, 16 CLI tests passed; swift build --product ttfx and bash -n capture.sh passed. Runtime print capture --max-frames 240: real Rust and Swift CLI 53 frames; ffprobe CLI 384x192,25/1,53 frames; full ffmpeg decode passed. Separate --max-frames 1 capture: two dumped frames, one encoded, completed=false. V01 commit 789a046: 149 additions + 18 deletions = 167 authored changed lines. Record observed RED/GREEN, commit identities, authored counts and runtime evidence here. V01 rollback: capture/model/script/tests/docs for the optional track. V02 rollback: player/pane/tests and generated CLI media; existing tracks preserved.

V02 observed RED: comparison tests failed compilation because player.swiftCLI was absent. GREEN: 18 comparison tests pass, including generated-library fourth readiness/advance/pause/seek/end-frame/cleanup; CLI suite 16 passes; both ttfx and TTFXComparisonApp builds and bash syntax check pass. App bundle smoke ./script/build_and_run.sh --compare --verify passed (process presence only; no visual assertion).
Runtime ./tools/video-comparison/capture.sh regenerated 37 four-track sets at 2026-09-17T20:39:38Z: 148 videos, 50,464 encoded frames, zero incomplete. python3 /tmp/validate-swift-cli-library.py checked ffprobe frame count/384x192/FPS25/1 and full ffmpeg decode for every video, and exact UTF-8 framing/count/cap metadata for all 74 executable dumps. Generated validation.json records the actual CLI binary .build/arm64-apple-macosx/debug/ttfx SHA256 c488c36416b1aab8c1fdb73eca6cc6394a959de32811e992e5cad70980a2e5b6. Existing Rust, SwiftUI and Metal tracks retained. Missing ignored generated library now explicitly skips runtime integration, not silent passing.
No failed required checks remain. Initial sandbox Swift test was unavailable due to toolchain cache permission; approved escalation allowed genuine RED/GREEN. No remote operations, PR, merge, native review, or unrelated CLI portability changes. Slice 1 is V01 789a046; slice 2 V02 5733760 (109 additions + 33 deletions = 142 authored lines; both behavior commits total 309). Rollback V01 restores old capture/model/script/docs/tests; rollback V02 removes fourth player/pane/tests and optional generated CLI files without deleting old tracks.

Independent parent-authorized verifier: 18 comparison and 16 CLI tests passed; bash syntax passed; all 74 dumps parsed; manifest reconciled 37 effects/148 videos/50,464 frames, current CLI SHA matched; print/rings ffprobe and full decode passed. Parent spot check bash syntax passed. No source blocker observed. No visual UI assertion or Windows/Linux certification.

## Next step
Parent independent verification and Engram mirror synchronization, then user-authorized local fast-forward merge to master. Push and PR remain unauthorized. Existing cross-platform CLI task document remains pending, not overwritten.
