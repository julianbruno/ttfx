# Design: Standalone Swift GUI App

## Technical Approach

Add a small standalone SwiftUI app, `TTFXGalleryApp`, on top of the existing native Swift package. The app owns GUI-specific lifecycle, state, and controls while delegating effects and rendering to the existing `ttfx-swift` and `TTFXSwiftUI` products.

The implementation MUST begin with tests. App source and package wiring are added only after focused RED tests describe the behavior being introduced.

## Target Structure

Preferred SwiftPM-first structure:

```text
Package.swift
Sources/
├── TTFXGalleryApp/
│   ├── TTFXGalleryApp.swift
│   ├── TTFXGalleryRootView.swift
│   ├── TTFXGalleryViewModel.swift
│   └── TTFXGalleryControlsView.swift
└── existing package targets...
tests/
├── TTFXGalleryAppTests/
│   ├── TTFXGalleryAppWiringTests.swift
│   ├── TTFXGalleryViewModelTests.swift
│   └── TTFXGalleryAccessibilityTests.swift
└── existing test targets...
```

The exact filenames may change during implementation, but the ownership boundaries SHOULD remain: app entrypoint and views in the app target, deterministic state in an app view model, and reusable renderer behavior in `TTFXSwiftUI` only when proven by tests.

## Target Decision and Fallback

### Primary Decision: SwiftPM First

The app SHOULD be represented as a SwiftPM app/executable target when that gives a clean macOS app lifecycle, imports `TTFXSwiftUI` and `TTFXEffects`, and can be opened or built from Xcode without duplicating package metadata.

### Explicit Fallback: Xcode Project/Workspace

If SwiftPM cannot create a viable standalone app bundle, app scheme, or platform lifecycle, implementation MAY add an Xcode project or workspace. The fallback MUST be justified by an observed RED test or build failure and MUST keep package products as the implementation source of truth. The Xcode project MUST NOT fork effect or renderer code.

## App Lifecycle

- `TTFXGalleryApp` owns the SwiftUI `App` entrypoint for supported platforms.
- macOS is the first-class launch path.
- iOS Simulator MAY share the same app lifecycle only when platform gates remain clean.
- Platform-specific code SHOULD be isolated with narrow `#if os(macOS)` / `#if os(iOS)` gates.
- The initial scene SHOULD open a single gallery window containing controls and a live preview.

## State and View Model

The app view model owns app-specific state:

- selected effect name
- editable input text
- seed
- canvas width and height within safe bounds
- play/pause state
- frame-rate or tick cadence
- current frame index / renderer tick state
- renderer status and fallback mode

The gallery source of truth MUST be `EffectRegistry.names`. The app view model SHOULD expose an immutable list in registry order and SHOULD derive the deterministic initial selection from the first registry entry unless an accepted later design says otherwise.

Effect changes SHOULD reset or reinitialize renderer state deterministically for the selected seed, text, and canvas. Reset MUST return to the same initial frame for identical state.

## Renderer Integration

Use existing `TTFXSwiftUI` APIs as the app's primary rendering seam:

- `TTFXFrameSnapshot`
- `TTFXRenderableCell`
- `TTFXFrameRenderer`
- `TTFXDeterministicRenderer`
- Metal availability/upload/command plan seams
- `TTFXFrameView`
- `TTFXGalleryView`
- `TTFXRendererStatusView`
- platform-gated `TTFXMetalFrameView`

The app SHOULD compose these APIs rather than duplicating renderer logic. If the app needs a reusable seam that is not available, add the smallest `TTFXSwiftUI` API after a failing test proves the need.

## Metal and Fallback Strategy

- Use Metal-backed rendering when platform and device availability permit.
- Use deterministic snapshot/SwiftUI frame rendering when Metal is unavailable, disabled, or unsuitable for tests.
- Headless tests MUST NOT require a real drawable.
- Drawable-backed manual validation MAY be documented for visual confirmation, but automated tests SHOULD target deterministic renderer state, upload plans, command plans, and snapshots.
- The app MUST surface renderer status so users and tests can distinguish Metal and fallback modes.

## Controls and Accessibility

The root view SHOULD provide:

- app title
- effect picker
- editable text field
- seed field
- canvas width and height controls
- play/pause button
- reset button
- frame-rate control when implemented
- live preview
- optional debug/status metadata panel

Interactive controls MUST have stable accessibility labels. The preview MUST expose visible text or a meaningful accessibility summary.

## Test Seams

Tests SHOULD use Swift Testing (`import Testing`, `@Test`, `#expect`) under lowercase `tests/` paths. Useful seams include:

- app target import smoke tests
- gallery count/order comparison against `EffectRegistry.names`
- deterministic view model state transitions
- play/pause/reset tick behavior
- renderer fallback behavior without a real drawable
- accessibility labels on root controls where feasible
- production-code prohibition scans for forbidden subprocess/fixture use in app source

## Strict TDD Strategy

Every implementation task must capture RED before GREEN.

1. Write the smallest behavior-level test for package/app target wiring, gallery order, view model transitions, renderer integration, or UI accessibility.
2. Observe the intended failure.
3. Implement only the production change needed for that test.
4. Re-run the focused test and observe GREEN.
5. Add a material negative or alternate case when it protects the contract.
6. Refactor only while focused tests remain green.

Implementation MUST NOT skip RED evidence for app source/tests. If a build-system limitation cannot be expressed as a unit test, capture the failing focused build command as RED before adding the fallback.

## Platform Support

| Platform | Decision |
|---|---|
| macOS | First-class target and required local app launch path. |
| iOS Simulator | Opportunistic; include only when target wiring and app lifecycle remain clean. |
| Linux/Windows | Out of scope for the standalone SwiftUI app. |

## Review Workload Forecast

The expected implementation should fit the `single-pr` delivery strategy and 6000 changed-line review budget if kept to:

- app target/package wiring
- focused app tests
- one app view model
- a small set of SwiftUI views
- minimal renderer seam additions only when test-proven
- concise run documentation

If implementation approaches the 6000-line budget, defer optional iOS Simulator support, advanced debug panels, and per-effect controls before expanding scope.

## Open Questions

None blocking for SDD artifacts. Implementation must still prove whether SwiftPM app bundling is sufficient before using the Xcode project fallback.
