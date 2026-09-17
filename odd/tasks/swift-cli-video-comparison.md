# Swift CLI video comparison track

## Outcome and scope
Add actual pure-Swift executable ANSI output as a fourth independently hideable track in TTFX Video Comparison. Capture the executable, not relabeled SwiftUI/Metal frames. Preserve legacy two/three-track libraries and existing renderers. CLI source/dependency portability work remains separate and pending.

## Decisions and checks
- User authorized implementation; technical artifacts English.
- Strict TDD explicitly enabled: observed RED then GREEN/REFACTOR; swift test.
- RDD off globally; no native review. Local commits authorized by ODD; no push/PR/merge/remote operations.
- Branch codex/cross-platform-cli; starting checkpoint c3d221e. Rust reference 0f24d88408c8b815761c2c07da7dc9b411f63016.
- Delivery ask-on-risk with user-selected stacked-to-main; two coherent local slices if required. Forecast 300–450 authored changed lines, generated videos excluded. Never compress code to fit budget.
- Video recording is macOS-only artifact tooling; CLI remains GUI-free. No claim of Windows/Linux certification.

## Tasks
- [x] V01: Capture real Swift CLI --parity-dump output with shared Rust/CLI arguments; store frames/video and optional swiftCLI manifest metadata/provenance. Legacy decode and track validation regression tests; CLI subprocess behavior/cap tests; setup docs and capture script build.
- [ ] V02: Fourth synchronized player and independently hideable Swift CLI pane; missing-recording notice for older libraries. Load/clear/readiness/play/pause/seek regression tests. Generate all 37 effect libraries with the added track and verify metadata/decoding/frame counts; report failures without claiming animation parity.

## Verification
Required: swift test --filter TTFXComparisonTests; swift test --filter TTFXCLITests; swift build --product ttfx; swift build --product TTFXComparisonApp; bash -n tools/video-comparison/capture.sh. Runtime: first single-effect print capture then all-effect capture, ffprobe frame/dimension/fps and full decode, generated-library player integration. App launch smoke when supported. Each task includes tests/docs and one conventional work-unit commit, exact focused/runtime proof and rollback boundaries.

## Progress and slices
V01 observed RED: swift test --filter TTFXComparisonTests failed compilation for missing swiftCLI/ansiDump/dumpArguments. GREEN: 17 comparison tests, 16 CLI tests passed; swift build --product ttfx and bash -n capture.sh passed. Runtime print capture --max-frames 240: real Rust and Swift CLI 53 frames; ffprobe CLI 384x192,25/1,53 frames; full ffmpeg decode passed. Separate --max-frames 1 capture: two dumped frames, one encoded, completed=false. V01 commit identity recorded after commit. Record observed RED/GREEN, commit identities, authored counts and runtime evidence here. V01 rollback: capture/model/script/tests/docs for the optional track. V02 rollback: player/pane/tests and generated CLI media; existing tracks preserved.

## Next step
Implement V01 then V02 in one sequential writer, with each coherent task committed independently and mirror owned by parent. Existing cross-platform CLI task document remains pending, not overwritten.
