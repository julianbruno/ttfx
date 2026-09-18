# Comparison playback test fixtures

## Objective and authorized scope
Fix four playback test failures caused by absent print/rings recordings. Tests and test support only; preserve real AVPlayer runtime assertions and do not alter user recordings.

## Problem and approach
A local generated manifest can exist without named effects. Tests must own tiny temporary playable fixtures rather than depend on optional capture output. Generate H.264 clips with AVFoundation, clean up per test, and also migrate profile playback tests to the same fixture.

## Constraints and checks
Strict TDD enabled by session configuration. Runner: `swift test --filter TTFXComparisonTests`. Delivery: ask-on-risk; forecast under 400 authored lines. No push. Parent owns feature branch and commit.

## Tasks
- [x] T1 Reproduce existing failures (RED: 37 tests, 4 issues; missing named print/rings effects).
- [x] T2 Provide deterministic temporary playable media and migrate integration tests.
- [x] T3 Verify full comparison suite and `git diff --check` (GREEN), record runtime evidence.

## Evidence and next step
RED: 37 tests, four missing-effect failures. GREEN: 38 tests passed in 4.597 seconds; no playback tests skipped. AVPlayer advancement, pause, seek, speed changes, profile changes, synchronized looping and short-track hold assertions retained and passed. Added encoded duration/track/cleanup regression. git diff --check passed. Media generated via AVFoundation in unique temporary folders; no external ffmpeg or local corpus required. One attempted run was blocked by compiler cache sandbox access; approved escalated runs succeeded. Next: parent structural readback, spot check and work-unit commit (commit identity pending).

## Rollback boundary
Remove fixture support and restore playback integration/profile test setup; no production behavior changes.
