# Synchronized comparison playback speed

## Outcome and scope
Add a native playback-speed selector from0.5× through3×, default1×. Apply rate to all present AVPlayers, including hidden optional tracks, and shared timeline. Change speed during playback without restarting or jumping media position; paused change must not auto-play. Preserve seeks/end clamp/shorter final-frame behavior. English artifacts, no encoded-video/capture changes.

## Workflow and constraints
User authorized implementation; ODD strict TDD explicit session/config, swift test with observed RED/GREEN/REFACTOR. RDD off; no remote/push/PR/merge. Starting codex/comparison-effect-selector411c049 with uncommitted authorized Source-footer removal. Preserve that removal and commit it separately if needed; never restore it. New branch codex/comparison-playback-speed inherits previous UX changes. Forecast under300 authored lines; existing stacked-to-main preference, no code compression.

## Tasks
- [x] S01: Validated speed state and shared-clock rebase/rate scheduling; all four tracks and timeline advance at selected rate, preserve paused/playing transitions and endpoint. Unit tests bounds/default/scaled elapsed/rebase and real generated-video integration at0.5×/3× including live change.
- [ ] S02: Accessible compact native speed picker near playback controls (0.5,0.75,1,1.25,1.5,2,2.5,3×); guide, tests/build/launch and actual UI rate-change smoke. Record local commit/proof/rollback and honest limitations.

## Checks and acceptance
swift test --filter TTFXComparisonTests; swift build --product TTFXComparisonApp; ./script/build_and_run.sh --compare --verify; git diff --check. Real video assertions confirm AVPlayer rates and scaled timeline/position with tolerant wall-clock checks; pure deterministic elapsed calculation tests avoid timing flakiness. No visual/VoiceOver claim from compiler tests. Parent CUA when available.

## Progress and next step
Explored player: scheduled rate currently1, timer elapsed unscaled; rate change requires shared position rebase and one host deadline. Delegate bounded writer then independent functional verifier; parent full mirror. Source removal remains pending and prior push question unanswered; no push inferred.

## Rollback
Revert only speed state/rebase/picker/tests/guide additions; keep prior toggle/selector/footer improvements. Capture and effect algorithms untouched.

## S01 evidence
- RED: `swift test --filter TTFXComparisonTests` failed compiling missing speed setter/state/media-clock API before implementation (initial sandbox cache refusal retried with approved access).
- GREEN: same command passed 23 tests, including generated four-track rings playback at 0.5×, live transition to 3×, shared time/rates, pause, unchanged-rate no-op and endpoint.
- REFACTOR: extracted shared scheduling and pure media-position calculation; tests green.
- RDD disabled; ordinary verification, no review lifecycle.
- Runtime rollback: remove speed state/rebase/scheduling additions and their tests, leaving footer and prior UX intact.
- S01 commit: recorded in S02 evidence after commit creation.
