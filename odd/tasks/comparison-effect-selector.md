# Comparison effect selector

## Outcome and scope
Improve the existing native sidebar selector with clear search, lightweight name/status rows, recording availability and no-results feedback. Preserve stable effect IDs, registry order, keyboard list selection and selected playback while searching. No effect algorithm/capture/player or track-control redesign. English artifacts.

## Workflow
ODD strict TDD from session/config/user, swift test with observed RED/GREEN. RDD off. Starting branch codex/comparison-track-controls at 01b94d0; selector branch inherits prior toggle work. Local conventional work-unit commit, no merge/push/PR/remote. Forecast under250 authored lines, stacked-to-main preference retained.

## Tasks
- [x] E01: Native searchable sidebar with accessible one-icon/two-line rows, recording status and filtered counts. Trim case-insensitive queries; useful empty state with clear-search action. Preserve selection/search behavior and explicit selected-effect missing-recording guidance. RED/GREEN tests for filtering/order/status/stable identifiers.
- [x] E02: Build/test/app smoke and actual selector UI interaction where available, update guide and capture proof/rollback/commit.

## Checks
swift test --filter TTFXComparisonTests; swift build --product TTFXComparisonApp; ./script/build_and_run.sh --compare --verify. No unrelated changes. Native sidebar backgrounds/highlight, labels and accessibility, no card grid or multiple inline utility buttons. Actual CUA search/no-results/clear/selection check; disclose unavailable keyboard/VoiceOver scenarios.

## Progress
E01 implemented in `ComparisonEffectSidebar.swift`: native source-list rows, recording status/track count, trimmed case-insensitive search, matching/recorded footer, Clear search empty state, stable-ID selection guard. Root supplies registry IDs unchanged; missing recordings show the exact single-effect capture command. Guide updated.

Verification of writer candidate:
- RED: `swift test --filter TTFXComparisonTests` failed because the new selector type did not exist (recorded `/tmp/selector-red.log`). Initial sandbox attempt was toolchain-cache blocked, not RED; rerun with cache access observed the intended missing-type failure.
- GREEN: same command passed 21 tests (2 new selector behavior tests), including ordered raw identifiers, trimming/case matching, summary counts, recording/limited/missing statuses, and filtered selection acceptance.
- REFACTOR: extracted sidebar/presentation logic from root; GREEN remains 21 tests.
- `swift build --product TTFXComparisonApp`: passed.
- `./script/build_and_run.sh --compare --verify`: passed, built bundled app and verified launch.
- `git diff --check`: passed.
- Actual UI search/no-results/clear/selection and keyboard scenarios: parent check pending. VoiceOver and narrow-window behavior not inferred from compile/launch.
- RDD off, review not launched. No capture/player/track-control mutation.

Commit identity and actual authored line count: parent records commit returned by writer after commit (avoid self-referential hash).

## Rollback and next step
Selector component/presentation tests/root integration/guide/task evidence can be reverted without touching track controls or video capture. Parent independent check, actual CUA interaction, commit identity/count and full Engram mirror remain before E02 closure.

## Final evidence
Commit c3916cf: 176 authored added/deleted lines. Parent CUA verified query "  RINGS  " matches one effect while current Print playback remains unchanged; unknown query shows no-results and Clear search, zero count; Clear restores all37 and Print selection. Click Rings loads1398 frames; Down selects Scattered73frames. Actual screenshot inspected. Independent verifier repeated all21 comparison tests and diff check, source inspection found no defect. Actual missing-recording/narrow-window/VoiceOver runtime untested. No merge or push.
