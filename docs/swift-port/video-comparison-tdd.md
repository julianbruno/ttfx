# Video comparison TDD evidence

The toggle, effect-selector, playback-speed, and loop changes were implemented test-first. The footer removal was a mechanical presentation change, checked by diff rather than a new behavioral test. These checks do not prove Rust/Swift effect parity or cross-platform CLI portability.

## Run the checks

From the repository root:

```sh
swift test --filter TTFXComparisonTests
swift build --product TTFXComparisonApp
./script/build_and_run.sh --compare --verify
git diff --check
```

The current comparison suite passes **28 tests**. Generated-video integration requires `artifacts/video-comparison/manifest.json`; when unavailable, those tests are explicitly skipped, not evidence of successful playback. The launch command verifies the process, not UI behavior.

## Recorded RED → GREEN → REFACTOR

| Change | RED observed before implementation | GREEN and refactor |
|---|---|---|
| Optional-track toggles | `optionalTrackControlsExplainIndependentVisibility` failed to compile because `OptionalComparisonTrack` did not exist. | 19 comparison tests passed; extracted a separate control component sharing tested presentation metadata. |
| Effect selector | New selector tests failed to compile because the selector type did not exist. | 21 comparison tests passed; extracted sidebar/presentation logic with stable identifiers. |
| Playback speed | New state/setter/media-clock tests failed to compile because the speed APIs did not exist. | 23 comparison tests passed; extracted shared rate scheduling and pure elapsed-to-media-position calculation. |
| Synchronized loop | New default/state and repeated-four-track tests failed to compile because `isLooping` did not exist. | 28 comparison tests passed; restart uses existing common host-clock rate scheduling without asynchronous seek races, and endpoint handling is shared with speed changes. |
| Loop unavailable endpoint correction | `loopCannotRestartLoadingOrFailedPlayersAtEndpoint` failed with position **0.5 instead of 3 seconds** after reducing the rate with Loop enabled but players unready. | Stop with the old-rate snapshot before assigning the new speed unless the shared loop is ready. |
| Endpoint correction | `slowingAtEndpointKeepsFinalPositionBeforeTimerUpdate` failed with position **0.5 instead of 3 seconds** after changing 3× to 0.5× at the endpoint. | 24 comparison tests passed after stopping with the old rate before assigning the new rate; minimal injected uptime enables deterministic regression testing. |

All rows used `swift test --filter TTFXComparisonTests`. Initial sandbox compiler-cache failures were environmental blockers, not RED evidence. A typo in the endpoint test's initializer argument order was fixed before observing the behavioral RED above.

## What is covered

- `optionalTrackControlsExplainIndependentVisibility`: labels, help, accessibility presentation metadata, and independent visibility semantics; not rendered pixels or spoken VoiceOver output.
- `selectorFiltersTrimmedQueryWithoutChangingRegistryIDsOrOrder`: trimmed case-insensitive search, registry identifiers/order, and selection acceptance.
- `selectorDistinguishesMissingPartialAndLimitedRecordings`: availability/status summaries.
- `playbackSpeedRejectsInvalidRatesAndScalesMediaClock`: 1× default, accepted rates, rejected nonfinite/out-of-range values, paused state, elapsed scaling, and endpoint clamp.
- `playbackSpeedKeepsFourTracksSynchronizedAcrossLiveChange`: generated `rings` videos at 0.5× and 3×, live transition continuity, unchanged-rate no-op, four AVPlayer rates/media positions, paused changes, and stopping at the endpoint.
- `slowingAtEndpointKeepsFinalPositionBeforeTimerUpdate`: deterministic old-rate endpoint snapshot before a slower rate, preserved final position, stopped state, and zero rates on all four players.
- `loopDefaultsOffAndNeverStartsPausedPlayback`: independent default-off state, retained speed, and paused seek/toggle behavior.
- `loopRepeatsFourTracksTogetherAndDisablesAtNextEndpoint`: actual generated `print` media, at least two loop boundaries at 3×, all four AVPlayer rates and media positions, stop after disabling, explicit pause and endpoint seek.
- `loopHoldsShorterLegacyTrackAndHandlesEndpointSpeedChange`: a two-track library using actual media with a longer shared timeline; the shorter track holds rather than restarting early, both restart at the shared boundary, and an injected endpoint clock preserves looping on a speed change.
- `loopCannotRestartLoadingOrFailedPlayersAtEndpoint`: unready endpoint guard; the existing invalid-media integration check additionally enables Loop and verifies a failed item never starts playback.
- Existing `pairedPlayersAdvanceAndPauseOnGeneratedVideos`, `swiftCLIPlayerLoadsPausesAndClearsLegacyTrack`, and `shorterVideoHoldsFinalFrameWithoutStretching` remain in the suite.

## Separate UI evidence and limits

Parent CUA checks recorded independent toggle off/on behavior, selector search/no-results/clear/keyboard selection without interrupting the current effect, active speed selection from 0.5× to 3×, and changing to 1× while paused without moving the position. These are manual UI observations, not automated TDD assertions.

Parent CUA additionally observed Loop off by default, enabling Loop while paused without autoplay, 3× playback still active after multiple cycle durations, and disabling Loop ending at 2.12 seconds with 3× retained. These sparse UI observations do not prove frame-perfect rendering.

Actual VoiceOver narration, narrow-window interaction, scene restoration, every speed on every effect, and every shorter-track endpoint combination are not claimed as verified. Source revision remains in the capture manifest; only its footer text was removed.

For historical command results and work-unit commits, see `odd/tasks/comparison-track-controls.md`, `odd/tasks/comparison-effect-selector.md`, `odd/tasks/comparison-playback-speed.md`, and `odd/tasks/comparison-playback-loop.md`.
