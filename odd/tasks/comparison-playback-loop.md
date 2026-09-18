# Synchronized video comparison loop

## Outcome
Add an independent accessible Loop toggle beside speed/playback. Default off. When enabled, restart all present tracks together only at the longest track endpoint, preserving selected speed. Shorter tracks hold final frame until shared loop boundary. Pause/seek remain explicit and do not auto-play. Disabling loop does not interrupt playback, but next endpoint stops. Failed playback never loops.

## Workflow
ODD strict TDD always by explicit user; swift test observed RED/GREEN/REFACTOR. English artifacts. RDD off. Starting codex/comparison-playback-speed5f7fda0, new codex/comparison-playback-loop. Local conventional work-unit commits, no push/merge/PR/remote. Forecast under250 authored lines; stacked-to-main preference. No effect/capture/generated-video changes.

## Tasks
- [x] L01: Loop state and shared endpoint restart with speed retained; test default/off, multiple synchronized cycles, shortest track no premature restart, disable and explicit pause/seek/error safety. Meaningful RED before source.
- [x] L02: Independent Loop toggle accessibility/help/state near speed; guide/README/TDD evidence, functional build/launch and actual UI smoke where available; commit/proof/rollback.

## Checks
swift test --filter TTFXComparisonTests; swift build --product TTFXComparisonApp; ./script/build_and_run.sh --compare --verify; git diff --check. Generated print videos support multiple fast loops at3×; injected clock endpoint unit proof. Four actual AVPlayer media times/rates remain synchronized, legacy optional missing tracks supported. Do not infer visual or VoiceOver proof from compile; parent CUA.

## Progress and next step
Implemented one shared endpoint restart using setRate(time:atHostTime:), with no asynchronous seek at loop boundaries. Both task outcomes form cohesive work-unit commit bcbc4e5 (feat(comparison): loop synchronized video playback), 204 additions +9 deletions =213 authored changed lines; no source/media parity changes. RDD off; no native review started.

RED: swift test --filter TTFXComparisonTests failed compilation on missing isLooping before implementation (/tmp/ttfx-loop-red.log). A focused unavailable-loop endpoint regression then failed position0.5 versus3 after slowing, before correcting old-rate stopping (/tmp/ttfx-loop-endpoint-red.log).
GREEN: swift test --filter TTFXComparisonTests passed28 tests, zero skipped, after final correction (3.826 seconds). swift build --product TTFXComparisonApp and ./script/build_and_run.sh --compare --verify exited0; git diff --check passed. Cache permission failures were environmental, not RED.
Parent CUA: defaultoff; enablepaused retainedPlay/position0; speed3 with Loopon continuedPause after many2.12-second cycles at media0.40; turningLoopoff reached2.12/Play with speed3 retained. Not VoiceOver/frame-perfect proof.

Next: parent mirror/readback and independent verification. Running behavior-unit authored count213, under250 forecast; stacked-to-main preference, no PR/push/merge authorized.

## Rollback
Loop state/endpoint behavior/toggle/associated tests/docs only; preserve speed/toggle/selector/footer and capture behavior.

## Final independent verification
Independent verifier repeated swift test --filter TTFXComparisonTests:28 passed, zero skipped,3.835s. No endpoint/speed/failure/state defect found. Parent structural readback and diff-check passed; CUA proof above retained. No push or merge performed. Implementation bcbc4e5; commit-proof59a3e43.
