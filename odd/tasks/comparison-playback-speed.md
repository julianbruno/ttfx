# Synchronized comparison playback speed

## Outcome and scope
Add a native playback-speed selector from0.5× through3×, default1×. Apply rate to all present AVPlayers, including hidden optional tracks, and shared timeline. Change speed during playback without restarting or jumping media position; paused change must not auto-play. Preserve seeks/end clamp/shorter final-frame behavior. English artifacts, no encoded-video/capture changes.

## Workflow and constraints
User authorized implementation; ODD strict TDD explicit session/config, swift test with observed RED/GREEN/REFACTOR. RDD off; no remote/push/PR/merge. Starting codex/comparison-effect-selector411c049 with uncommitted authorized Source-footer removal. Preserve that removal and commit it separately if needed; never restore it. New branch codex/comparison-playback-speed inherits previous UX changes. Forecast under300 authored lines; existing stacked-to-main preference, no code compression.

## Tasks
- [x] S01: Validated speed state and shared-clock rebase/rate scheduling; all four tracks and timeline advance at selected rate, preserve paused/playing transitions and endpoint. Unit tests bounds/default/scaled elapsed/rebase and real generated-video integration at0.5×/3× including live change.
- [x] S02: Accessible compact native speed picker near playback controls (0.5,0.75,1,1.25,1.5,2,2.5,3×); guide, tests/build/launch and actual UI rate-change smoke. Record local commit/proof/rollback and honest limitations.

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
- S01 commit: `d32cea1` (124 additions, 8 deletions including task document); footer checkpoint `94d55a0`.

## S02 implementation and checks
- Native menu picker beside Play offers eight labeled speeds with accessibility label and help; shared selected state drives validated setter. Guide updated with paused/live semantics and source-media time meaning.
- `swift test --filter TTFXComparisonTests`: 23 passed after UI wiring.
- `swift build --product TTFXComparisonApp`: passed.
- `./script/build_and_run.sh --compare --verify`: exit 0; app launched for parent UI smoke.
- `git diff --check`: passed.
- Parent actual UI smoke pending; no visual or VoiceOver result claimed by writer. S02 remains open until parent observation.
- Rollback: revert picker/caption/guide additions only; runtime can be separately reverted via S01.
- Next step: parent UI smoke and independent verification, then update full Engram mirror. No push/merge/PR performed.

## TDD evidence and endpoint correction
- Initial RED: speed tests failed for missing speed state/setter/media-clock APIs; GREEN: 23 tests. REFACTOR: shared scheduling and pure media-position calculation.
- Independent verification found endpoint ordering: an old-rate snapshot at duration was recomputed by pause with the new slower rate against the old anchor, moving position backward.
- Regression `slowingAtEndpointKeepsFinalPositionBeforeTimerUpdate`: minimal injected uptime fixes elapsed at 1 second with duration 3 and old speed 3×. Observed RED: `player.position` was 0.5 instead of 3; 24 tests failed with one issue. A test argument-order typo was corrected before this behavioral RED.
- Fix: pause at the sampled endpoint while the old speed is still active, then assign the new speed. No reschedule or auto-play at the endpoint.
- GREEN: `swift test --filter TTFXComparisonTests` passed 24 tests, including deterministic regression and generated four-track integration. `swift build --product TTFXComparisonApp` passed; `git diff --check` passed.
- REFACTOR: the injected uptime closure defaults to real monotonic uptime; no new dependencies or scheduling abstraction.
- UI commit: `b938822`. Parent observed actual active 0.5×→3× picker change and paused 1× change preserving position; VoiceOver narration and every shorter-track/rate combination remain untested.
- TDD guide: `docs/swift-port/video-comparison-tdd.md`; historical toggle/selector RED/GREEN are attributed to their existing task records, footer removal is explicitly diff-only.
- Correction commit identity and final independent verification: parent records after commit. No remote operation.

## Final observed evidence
Correction commit11e587b; independent verifier reran24 comparison tests with no skips and confirmed endpoint ordering fixed. Parent CUA selected0.5× while paused (position0), pressedPlay, selected3× while playing (Pause remained active and media timeline advanced), paused then selected1× without moving18.76s or autoplay. Sparse UI samples prove interaction, not a universal no-jump measurement; live continuity/all4 rates are covered by automated rings regression. Parent diff-check passed. Actual VoiceOver/every shorter-track combination untested. No push or merge.
