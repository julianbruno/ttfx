# Comparison track visibility controls

## Outcome
Replace stacked full-width switches with a compact, clearly labeled optional-track control group. Preserve Rust/Metal baseline panes and independent Swift CLI/SwiftUI visibility. Use native macOS controls, keyboard/accessibility labels, semantic colors and window-scoped visibility. Missing legacy tracks remain explained, not silently hidden. No capture/player behavior changes.

## Scope and workflow
Authorized UI/UX implementation; English artifacts. Strict TDD from user/session/config; runner swift test. RDD off. Local feature branch and conventional work-unit commit; no remote/push/PR/merge. Starting master 57dca0b. Forecast under 250 authored lines; existing stacked-to-main delivery preference. No code compression for size.

## Tasks
- [x] U01: Implement compact labeled native toggle/button group with clear selected state, icons and helpful track explanations; layout adapts to narrow width and keeps independent selection. Add meaningful state/metadata or UI-accessibility tests, observe RED/GREEN.
- [x] U02: Verify comparison tests/build and launch; inspect actual UI if host tools permit, document visual verification limits. Update short guide and record commit/proof.

## Checks and acceptance
swift test --filter TTFXComparisonTests; swift build --product TTFXComparisonApp; ./script/build_and_run.sh --compare --verify. Controls must have text plus non-color selected indication, keyboard operability, VoiceOver names/state and no single-select semantics. Rust/Metal remain unchanged; missing optional recordings retain notices. Avoid new global preferences or unrelated redesign.

## Progress
U01 implemented: native independent button-style toggles, icons, Visible/Hidden text and checkmark/circle cues, renderer hover help, VoiceOver name/value/hint and ⌘1/⌘2. ViewThatFits adapts the heading and controls independently. SceneStorage keeps visibility window-scoped. Rust/Metal and missing-track notices remain unchanged. Shared presentation metadata is used by both controls and tests; no new dependencies were introduced.

U02 functional checks complete:
- RED: `swift test --filter TTFXComparisonTests` exited 1 with missing `OptionalComparisonTrack` at the newly added presentation-contract test, before implementation. Initial sandbox-only attempt failed on compiler-cache permissions (not RED proof); authorized rerun reached the meaningful compile failure.
- GREEN: same command passed all 19 tests, including the new metadata/accessibility contract and existing playback/legacy-track integration tests.
- REFACTOR: component kept separate from root layout; no further changes necessary after GREEN.
- `swift build --product TTFXComparisonApp`: passed.
- `./script/build_and_run.sh --compare --verify`: passed, process smoke only; app is ready for parent visual inspection.
- `git diff --check`: passed.
- Actual UI interaction, narrow-window layout and VoiceOver runtime behavior are not yet visually verified; parent may append observed evidence. Tests validate shared labels/help, not rendered pixels or VoiceOver delivery.
- RDD: off; no native review invoked. No remote operations.

## Rollback boundary
Revert the control component, root visibility controls/SceneStorage, associated test, guide paragraph and this task record together. Capture, manifest and playback implementations are untouched.

## Commit evidence
Coherent UI/test/guide work-unit commit pending below; parent records its identity after creation to avoid a self-referential commit hash. Authored count remains below the 400-line delivery heuristic.

## Next step
Parent visual/interaction spot check, Engram mirror refresh and final outcome. No push, PR or merge authorized.

## Final evidence
Implementation commit: c838a0a (148 additions + 9 deletions = 157 authored lines). Parent CUA inspected the actual grouped controls screenshot; AX reports native toggle roles and Visible/Hidden values. Clicking Swift CLI off/on removed/restored only its pane; Cmd+2 off/on removed/restored only SwiftUI. Both restored visible. Independent verifier repeated 19 comparison tests and inspected committed code without defects. Narrow-window interaction, actual VoiceOver narration and SceneStorage restoration remain untested. No merge or push performed.
