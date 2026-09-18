# Comparison playback profiles

## Objective
Add a playback timing profile menu beside Speed, defaulting to None, for every comparison track.

## Scope and constraints
Playback-only; do not regenerate effects. Preserve pause, seek, looping, hidden tracks, and speed. Use SwiftUI's monotonic UnitCurve presets (Linear, Ease In, Ease Out, Ease In Out). Spring/overshooting animations are not forward-only media timelines. Profile changes retain media position. English UI.

## Tasks
- [x] T1: Add timing profiles, continuous shared clock, synchronized variable rates, picker and docs with tests. Full-suite fixture failures remain disclosed below.

## Checks
Strict TDD enabled by user AGENTS.md: RED then GREEN then refactor. Runner: swift test --filter TTFXComparisonTests. Also swift build --product TTFXComparisonApp and git diff --check.

## Delivery
Parent owns branch/commit and review. No push. Forecast: approximately 230 authored lines, ask-on-risk. Rollback: profile model, player timing changes, picker, focused tests and profile docs only.

## Progress
Exploration: existing AVPlayers share a host-clock start and 30 Hz media clock; constant-speed behavior remains unchanged for None/Linear. Runtime fixture library available when manifest exists. Implemented profile menu beside Speed and UnitCurve-based media clock. RED: swift test --filter PlaybackProfile failed missing PlaybackProfile/player APIs before source edits. GREEN: same focused command passed 3 tests (including 4.766 s generated-video harness). swift build --product TTFXComparisonApp passed. git diff --check passed.

Full regression: swift test --filter TTFXComparisonTests ran 37 tests; 4 existing integration tests fail fixture lookup because local manifest lacks print/rings. New runtime harness chooses an available complete four-track recording (beams) and passes pause/change/end/loop synchronization checks within 150 ms. No generated artifacts changed.

Independent read-only verification found no concrete pacing/state regression; `swift test --filter PlaybackProfile` passed 3 tests again. RDD remains off; no native review. Interactive UI not checked; 30 Hz rate updates approximate the timing curves. Parent integrates the work-unit commit in master; no push. Remaining follow-up: restore missing print/rings fixtures to rerun the full suite.
