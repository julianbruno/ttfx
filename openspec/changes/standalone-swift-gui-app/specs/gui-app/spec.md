# gui-app Specification

## Purpose

Define the required behavior for `TTFXGalleryApp`, a standalone SwiftUI GUI application for previewing native Swift TTFX effects through existing package libraries without using terminal subprocesses or fixture playback in production app code.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "MAY", and "OPTIONAL" in this specification are to be interpreted as described in RFC 2119.

## ADDED Requirements

### Requirement: Standalone App Target

The system MUST provide a standalone GUI app target named `TTFXGalleryApp` unless a later accepted change explicitly renames it. The app MUST use the native Swift package libraries rather than invoking command-line tools.

#### Scenario: App target imports package libraries

- GIVEN the repository package products include `ttfx-swift` and `TTFXSwiftUI`
- WHEN the standalone app target is built
- THEN the app target imports the native effects and SwiftUI renderer APIs directly
- AND the app target does not require a terminal CLI invocation to launch

#### Scenario: macOS first launch path

- GIVEN a developer opens the documented app target in Xcode on macOS
- WHEN the developer presses Run for the supported macOS destination
- THEN the standalone GUI app launches with the TTFX gallery root view

#### Scenario: iOS Simulator is opportunistic

- GIVEN iOS Simulator support would require duplicated lifecycle or fragile target wiring
- WHEN implementation chooses supported platforms
- THEN iOS Simulator support MAY be deferred
- AND the deferral MUST be documented

### Requirement: Gallery Source of Truth

The app MUST list all effects exposed by `EffectRegistry.names`. The app SHOULD preserve registry order. A different order MUST be justified by an accepted design update.

#### Scenario: All registry effects are shown

- GIVEN `EffectRegistry.names` contains 37 effect names
- WHEN the app gallery model is created
- THEN the gallery contains 37 entries
- AND every entry corresponds to one registry name

#### Scenario: Registry order is stable

- GIVEN `EffectRegistry.names` provides a stable order
- WHEN the app presents effect choices
- THEN the choices appear in that registry order
- AND the app does not prefer the existing demo gallery order when it differs

#### Scenario: Deterministic default selection

- GIVEN the app launches with no saved user selection
- WHEN the gallery state initializes
- THEN the selected effect is deterministic
- AND the initial selection is derived from the registry list

### Requirement: App Controls

The app MUST expose common controls for effect selection, text input, seed, canvas size, playback, reset, and preview state. Controls MUST update app state deterministically.

#### Scenario: User edits sample text

- GIVEN the gallery app is open
- WHEN the user changes the sample text field
- THEN subsequent rendered frames use the new text
- AND the renderer state is deterministic for the selected effect, seed, and canvas

#### Scenario: User changes seed

- GIVEN an effect is selected
- WHEN the user changes the seed
- THEN reset returns the preview to the first deterministic frame for that seed

#### Scenario: User changes canvas size

- GIVEN the canvas size controls are visible
- WHEN the user enters width or height outside safe bounds
- THEN the app clamps or rejects the invalid value
- AND the renderer does not crash

#### Scenario: User controls playback

- GIVEN the preview is running
- WHEN the user pauses playback
- THEN frame advancement stops
- WHEN the user resumes playback
- THEN frame advancement continues from the paused state

#### Scenario: User resets playback

- GIVEN playback has advanced beyond the initial frame
- WHEN the user activates reset
- THEN the preview returns to the deterministic initial frame for the current effect, text, seed, and canvas

### Requirement: Renderer Integration

The app MUST render native Swift effects through `TTFXSwiftUI` renderer and snapshot APIs. The app MUST NOT duplicate effect rendering logic in the app target.

#### Scenario: Deterministic renderer seam

- GIVEN fixed effect, text, seed, canvas, and frame-rate state
- WHEN the view model advances the renderer by a known number of ticks
- THEN the produced snapshots are deterministic
- AND the same inputs produce the same frames after reset

#### Scenario: Effect switch reinitializes renderer

- GIVEN one effect is selected and playback has advanced
- WHEN the user selects a different effect
- THEN the renderer reinitializes for the new effect
- AND stale frame state from the previous effect is not displayed as current output

#### Scenario: Renderer status is visible

- GIVEN the renderer chooses Metal or fallback mode
- WHEN the root view is displayed
- THEN the app exposes renderer status or metadata sufficient for users and tests to identify the active render path

### Requirement: Metal and Fallback Rendering

The app SHOULD use Metal-backed rendering when available. The app MUST provide a deterministic non-Metal fallback for unsupported platforms, unavailable devices, or headless tests.

#### Scenario: Metal is available

- GIVEN the platform supports Metal and the renderer availability check succeeds
- WHEN the preview is displayed
- THEN the app MAY use `TTFXMetalFrameView` through platform-gated code
- AND renderer state remains testable without depending on a real drawable

#### Scenario: Metal is unavailable

- GIVEN Metal is unavailable or disabled for a headless test
- WHEN the preview is displayed
- THEN the app uses a deterministic SwiftUI frame or snapshot fallback
- AND all core playback controls remain functional

#### Scenario: Drawable-backed visual claims

- GIVEN a validation claim requires real GPU display output
- WHEN automated tests do not use a real drawable
- THEN the claim MUST be marked as manual validation or deferred

### Requirement: Accessibility

The app MUST expose accessible labels or summaries for the root title, effect picker, playback controls, reset control, editable inputs, and preview.

#### Scenario: Required controls have labels

- GIVEN the root gallery view is constructed
- WHEN accessibility metadata is inspected
- THEN the effect picker, text input, seed input, play/pause button, reset button, and preview have meaningful labels or summaries

#### Scenario: Preview conveys meaning

- GIVEN assistive technology cannot inspect individual rendered cells
- WHEN the preview is focused
- THEN the app provides visible text or a meaningful summary of the selected effect and rendered content

### Requirement: Packaging and Build

The app MUST have a documented build and run path. SwiftPM MUST be preferred unless it cannot provide a viable app bundle or scheme; an Xcode project/workspace fallback MAY be used only with documented justification.

#### Scenario: SwiftPM-first target is viable

- GIVEN SwiftPM target wiring can build and expose a launchable app scheme
- WHEN implementation adds the app target
- THEN package metadata remains the primary source of truth
- AND no Xcode project fallback is required

#### Scenario: Xcode fallback is required

- GIVEN SwiftPM cannot provide a viable app bundle, scheme, or lifecycle
- WHEN implementation adds an Xcode project or workspace
- THEN the fallback references package products rather than copying effect or renderer source
- AND the failing SwiftPM evidence is documented

#### Scenario: Supported build destinations pass

- GIVEN the app declares macOS support and optional iOS Simulator support
- WHEN supported build commands are run
- THEN macOS MUST pass
- AND iOS Simulator MUST pass only if that platform was accepted as supported for this change

### Requirement: Production-Code Prohibitions

Production app code MUST NOT invoke Rust, the Swift CLI executable, terminal subprocesses, parity fixtures, fixture playback, or frame-dump table fallbacks. Production app code MUST use native Swift package APIs for effects and rendering.

#### Scenario: No subprocess rendering

- GIVEN production app source is inspected
- WHEN forbidden process APIs or CLI executable references are searched
- THEN no Rust subprocess, Swift CLI subprocess, shell command, or terminal rendering path is used to produce app frames

#### Scenario: No fixture playback

- GIVEN production app source is inspected
- WHEN fixture paths, parity dumps, or frame-dump table fallback identifiers are searched
- THEN the app does not use prerecorded frames as production preview output

#### Scenario: Native Swift rendering only

- GIVEN a user selects an effect in the standalone app
- WHEN playback advances
- THEN frames are generated from native Swift effect state and rendered through app/`TTFXSwiftUI` code
- AND no external executable or fixture table participates in production rendering

### Requirement: Strict TDD Evidence

Implementation MUST proceed through strict TDD for app source, tests, and build-system changes.

#### Scenario: Behavior test before production code

- GIVEN an implementation task adds app behavior
- WHEN work starts on that task
- THEN a focused RED test or failing focused build must be captured before production code is added
- AND GREEN evidence must be captured after the minimal implementation

#### Scenario: Refactor remains protected

- GIVEN focused tests are green
- WHEN implementation refactors app or renderer integration code
- THEN the focused tests remain green after the refactor
