# Tasks: Standalone Swift GUI App

## Review Forecast

Delivery strategy: `single-pr`  
Review budget: `6000` changed lines

Keep the implementation compact enough for one review by deferring optional iOS Simulator support, advanced debug panels, and per-effect option editors if the budget tightens. Do not mark implementation tasks complete until the corresponding RED/GREEN/REFACTOR evidence exists.

## 0. SDD Approval Gate

- [x] 0.1 Review `proposal.md`, `design.md`, `tasks.md`, and `specs/gui-app/spec.md`.
- [x] 0.2 Run or request OpenSpec validation for `standalone-swift-gui-app`.
- [x] 0.3 Confirm the target name remains `TTFXGalleryApp`.
- [x] 0.4 Confirm macOS-first with iOS Simulator only if app lifecycle remains clean.

## 1. Package/App Wiring

- [x] 1.1 RED: Add a focused import/build test proving no standalone app target currently imports `TTFXSwiftUI` and `TTFXEffects` as `TTFXGalleryApp`.
- [x] 1.2 GREEN: Add the minimal SwiftPM-first app target and app entrypoint needed to satisfy the wiring test.
- [x] 1.3 REFACTOR: Keep target metadata minimal; avoid adding an Xcode project unless the observed build failure proves SwiftPM is not viable.
- [x] 1.4 If SwiftPM app bundling is not viable, RED: capture the exact failing app build/open command, then GREEN: add the smallest Xcode project/workspace fallback.

## 2. Gallery Source of Truth

- [x] 2.1 RED: Add a test that the app gallery exposes all 37 entries from `EffectRegistry.names` in registry order.
- [x] 2.2 GREEN: Implement the app gallery model/view model list from `EffectRegistry.names`, not from the existing `TTFXGallery.demos` order.
- [x] 2.3 TRIANGULATE: Add a test that the deterministic default selection is the expected first registry entry.
- [x] 2.4 REFACTOR: Keep gallery derivation simple and remove any duplicated hard-coded effect tables.

## 3. App View Model and Controls State

- [x] 3.1 RED: Add tests for editable text, seed, canvas size bounds, selected effect, play/pause, reset, and frame-rate state.
- [x] 3.2 GREEN: Implement the smallest `TTFXGalleryViewModel` or equivalent reducer-like state to satisfy the tests.
- [x] 3.3 TRIANGULATE: Add tests for invalid canvas sizes and effect switching resetting renderer state deterministically.
- [x] 3.4 REFACTOR: Keep app-specific state in the app target; do not move it into `TTFXSwiftUI` unless a reusable seam is proven.

## 4. Renderer Integration

- [x] 4.1 RED: Add a deterministic renderer test proving play, pause, reset, and fixed seed/text/canvas produce expected frame progression through `TTFXSwiftUI` seams.
- [x] 4.2 GREEN: Connect the view model to `TTFXFrameRenderer` / `TTFXDeterministicRenderer` / snapshot types with the smallest production code.
- [x] 4.3 TRIANGULATE: Add a test for effect switching and seed changes reinitializing deterministic output.
- [x] 4.4 REFACTOR: Prefer composition of existing `TTFXSwiftUI` APIs; add new reusable APIs only when protected by tests.

## 5. Metal and Fallback Rendering

- [x] 5.1 RED: Add tests for renderer status and fallback behavior when Metal is unavailable or disabled in a headless path.
- [x] 5.2 GREEN: Wire `TTFXMetalFrameView` behind platform/availability gates and provide `TTFXFrameView` or deterministic snapshot fallback.
- [x] 5.3 TRIANGULATE: Exercise Metal availability/upload/command-plan seams without requiring a real drawable.
- [x] 5.4 REFACTOR: Isolate platform gates and avoid duplicating renderer code.

## 6. SwiftUI Root UI and Accessibility

- [x] 6.1 RED: Add UI/root view tests or inspection seams proving required controls and accessibility labels are absent.
- [x] 6.2 GREEN: Implement the root gallery screen with title, picker, text field, seed field, canvas controls, play/pause, reset, preview, and renderer status.
- [x] 6.3 TRIANGULATE: Add tests for visible preview summary and disabled/edge states where feasible.
- [x] 6.4 REFACTOR: Keep view composition readable and avoid introducing unrelated styling systems.

## 7. Production-Code Prohibitions

- [x] 7.1 RED: Add a focused scan or test proving app production code must not call Rust, Swift CLI subprocesses, fixture playback, or frame-dump table fallbacks.
- [x] 7.2 GREEN: Ensure app production code uses only native Swift package APIs and no forbidden subprocess/fixture paths.
- [x] 7.3 TRIANGULATE: Include common forbidden symbols/APIs such as `Process`, CLI executable names, fixture directories, and frame-dump table identifiers where practical.

## 8. Build, Launch, and Documentation

- [x] 8.1 RED: Capture the focused macOS build or launch command failing before final app wiring is complete.
- [x] 8.2 GREEN: Make the macOS app build pass.
- [x] 8.3 RED/GREEN: Add iOS Simulator build support only if lifecycle remains clean; otherwise document deferral.
- [x] 8.4 Add README/docs instructions for opening and running `TTFXGalleryApp`.
- [x] 8.5 Run focused app tests.
- [x] 8.6 Run existing Swift tests.
- [x] 8.7 Run supported Xcode build destinations.

## 9. Final Review Gate

- [ ] 9.1 Verify all acceptance criteria in the proposal.
- [x] 9.2 Confirm changed lines remain within the 6000-line single-PR review budget or document accepted scope reductions.
- [x] 9.3 Provide RED/GREEN/REFACTOR evidence for every implementation task.
- [ ] 9.4 Provide manual launch evidence for the macOS app.
