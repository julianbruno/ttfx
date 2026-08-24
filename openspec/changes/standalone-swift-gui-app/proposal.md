# Proposal: Standalone Swift GUI App

## Intent

Create `TTFXGalleryApp`, a standalone SwiftUI GUI application that embeds the native Swift `ttfx-swift` package and lets users preview and interact with every native Swift TTFX effect without using the terminal CLI.

## User-Facing Goal

Users can open a macOS app from Xcode, select any available TTFX effect, edit sample text and common playback parameters, and watch deterministic native Swift animation rendered through the existing `TTFXSwiftUI` APIs.

## Scope

### In Scope

- Add an app target named `TTFXGalleryApp` unless a later accepted design change renames it.
- Prefer a SwiftPM-first app target so package products remain the source of truth.
- Fall back to an Xcode project/workspace only if SwiftPM cannot provide a viable app bundle or scheme for local launch and tests.
- Use existing package products: `ttfx-swift` (`TTFXCore`, `TTFXEffects`) and `TTFXSwiftUI`.
- Present all 37 effects from `EffectRegistry.names` in registry order unless a later design explicitly justifies a different order.
- Provide common controls for effect selection, editable input text, seed, canvas size, play/pause, reset, and frame-rate behavior.
- Render through `TTFXSwiftUI` snapshot/gallery/renderer seams and use Metal when available.
- Provide deterministic fallback rendering when Metal is unavailable or unsuitable for headless tests.
- Add focused tests through strict TDD before implementing app source.
- Document how to open, build, and run the app.

### Out of Scope

- Replacing the Rust `ttfx` production CLI.
- Shelling out to Rust, the Swift CLI executable, fixture dumps, or frame-dump tables from production app code.
- Implementing Python/TTE plugin support.
- Implementing per-effect advanced option editors unless separately accepted.
- Claiming full visual GPU parity without real drawable-backed validation.
- Reordering the gallery to match the existing `TTFXGallery.demos` ordering when that differs from `EffectRegistry.names`, unless a future design records the reason.

## Target Platform Decision

The first supported target is macOS. iOS Simulator support is opportunistic and SHOULD be added only when the package/app lifecycle, target wiring, and test strategy remain clean. If iOS support requires fragile duplication or a separate lifecycle, defer it and document the reason.

## Dependencies

- Swift package products already present in `Package.swift`:
  - `ttfx-swift` library exposing `TTFXCore` and `TTFXEffects`.
  - `TTFXSwiftUI` library exposing frame snapshots, renderable cells, renderers, gallery/status views, and Metal seams.
  - Existing CLI executable `ttfx`, which MUST NOT be used by production app code.
- SwiftUI and platform app lifecycle APIs for macOS first.
- Metal when available, with SwiftUI/snapshot fallback when unavailable.
- Swift Testing (`import Testing`, `@Test`, `#expect`) for new tests under lowercase `tests/` directories, following existing repository convention.

## Risks

| Risk | Mitigation |
|---|---|
| SwiftPM may not provide a clean standalone app bundle/scheme. | Start with a SwiftPM-first target decision; use an Xcode project/workspace fallback only when a RED package/app lifecycle test proves SwiftPM is insufficient. |
| Metal behavior is difficult to prove in headless CI. | Test renderer upload/command-plan seams and fallback snapshots; reserve manual drawable-backed validation for visual claims. |
| Existing gallery order differs from `EffectRegistry.names`. | Specify registry order for the app and add a failing test before implementation. |
| App state may leak into reusable libraries. | Keep app-specific state in the app target; add library seams only when a failing test proves reusable behavior is needed. |
| Review size may grow beyond a single review. | Keep implementation tasks TDD-ordered and forecast against the `single-pr` delivery strategy and 6000 changed-line review budget. |

## Rollback Boundaries

- The app is additive and MUST NOT change the Rust CLI production path.
- If app target wiring fails, rollback removes the app target, app tests, and app documentation while leaving existing Swift libraries intact.
- If a reusable `TTFXSwiftUI` seam is added, it must be covered by focused tests and remain safe to keep even if the app target is deferred.
- Production app code MUST NOT introduce subprocess or fixture playback dependencies that would require deeper rollback across CLI/parity infrastructure.

## Acceptance Criteria

- [ ] OpenSpec change exists and validates for `standalone-swift-gui-app`.
- [ ] App target builds locally as `TTFXGalleryApp` or an accepted later name.
- [ ] App opens from Xcode as a standalone GUI app on macOS.
- [ ] Gallery lists all 37 `EffectRegistry.names` entries in registry order.
- [ ] At least one effect animates from native Swift state in the GUI.
- [ ] Play, pause, reset, effect selection, seed, text, and canvas controls have focused tests.
- [ ] Metal is used when available and a deterministic non-Metal/headless fallback is available.
- [ ] Root view and controls expose accessibility labels or meaningful summaries.
- [ ] Production app code contains no Rust subprocess, Swift CLI subprocess, fixture playback, or frame-dump table fallback.
- [ ] Focused GUI/app tests pass.
- [ ] Existing `swift test` passes.
- [ ] Supported Xcode build destinations pass, with iOS Simulator included only when lifecycle remains clean.
- [ ] README or docs explain how to open and run the app.

## Delivery

**Strategy**: single-pr  
**Review budget**: 6000 changed lines  
**Artifacts**: openspec  
**Next**: implement through strict TDD after proposal/design/tasks/spec approval.
