# Standalone Swift GUI App Spec

This spec defines a standalone GUI application that embeds the native Swift `ttfx-swift` package and presents the `TTFXSwiftUI` renderer as an end-user app. The work must be driven by SDD/OpenSpec artifacts and implemented with strict TDD evidence.

## Quick path

1. Create an OpenSpec change for the GUI app before implementation.
2. Add failing tests for app launch, gallery behavior, renderer state, and package wiring.
3. Implement the smallest native Swift app target that turns those tests green.
4. Verify with focused GUI tests, full Swift tests, and an Xcode build for macOS and iOS Simulator if supported.

## Goal

Create a standalone GUI app that lets users preview and interact with all 37 native Swift TTFX effects without using the terminal CLI.

The app must use the existing Swift package libraries:

| Product | Required use |
|---|---|
| `ttfx-swift` | Core frame/effect primitives and `TTFXEffects` registry. |
| `TTFXSwiftUI` | Frame snapshots, gallery models, renderer scheduling, and Metal-backed rendering bridge. |

## Non-goals

- Do not replace the Rust `ttfx` production CLI.
- Do not shell out to Rust, Swift CLI, or fixture dumps from production app code.
- Do not implement Python/TTE plugin support.
- Do not claim full visual GPU parity unless a real drawable-backed validation exists.
- Do not skip SDD artifacts for convenience.

## SDD workflow

Create a dedicated OpenSpec change, for example:

```text
openspec/changes/standalone-swift-gui-app/
```

Required artifacts:

| Artifact | Required content |
|---|---|
| `proposal.md` | User-facing app goal, scope, non-goals, and acceptance criteria. |
| `design.md` | Target structure, app lifecycle, renderer integration, test strategy, and platform support. |
| `tasks.md` | TDD-ordered implementation tasks with explicit RED/GREEN/REFACTOR gates. |
| `specs/gui-app/spec.md` | Normative requirements for app behavior, gallery, renderer, controls, and packaging. |

Recommended phases:

1. **Explore** existing `TTFXSwiftUI`, `TTFXEffects`, package targets, and Xcode/SPM constraints.
2. **Proposal** define the minimal standalone app and target platforms.
3. **Design** specify architecture and test seams.
4. **Tasks** split into reviewable work units.
5. **Apply** implement through strict TDD.
6. **Verify** run focused app tests, full Swift tests, and Xcode builds.

## Proposed app shape

| Area | Decision |
|---|---|
| App name | `TTFXGalleryApp` or `TTFX Demo`; final name decided in proposal. |
| Target type | SwiftUI app target, preferably SwiftPM-compatible if feasible; Xcode project only if required by app bundling. |
| Platforms | macOS first; iOS Simulator support if package/app lifecycle remains clean. |
| Rendering | Use `TTFXSwiftUI` snapshot/gallery APIs and Metal bridge where available. |
| Effects | List all 37 `EffectRegistry.names` entries. |
| Input | Default sample text plus editable text field. |
| Controls | Effect picker, seed field, canvas size, play/pause, reset, frame-rate control. |
| Output | Live animated preview and optional frame/debug metadata panel. |

## Architecture

```text
Standalone App Target
├── App entrypoint
├── Gallery screen
├── Effect controls
├── Preview renderer view
└── View model / reducer-like state
    ├── selected effect
    ├── sample text
    ├── seed/canvas/options
    ├── play/pause state
    └── renderer tick state

Package libraries
├── TTFXCore
├── TTFXEffects
└── TTFXSwiftUI
```

Keep app-specific state outside the library. Library changes are allowed only when a failing test proves the standalone app needs a reusable seam.

## TDD requirements

Every implementation task must show RED before GREEN.

| Test layer | RED examples | GREEN expectation |
|---|---|---|
| Package wiring | App target cannot import `TTFXSwiftUI` / `TTFXEffects`. | App target imports and builds. |
| Gallery model | App gallery count/order mismatches registry. | App lists all 37 effects in stable order. |
| View model | Selecting an effect does not reset renderer state. | Selection updates preview deterministically. |
| Renderer | Tick scheduler does not advance frames correctly. | Play/pause/reset produce deterministic snapshots. |
| UI smoke | Root view lacks required controls/accessibility labels. | UI exposes picker, text input, seed, play/pause, preview. |
| Xcode build | App scheme fails for target platform. | `xcodebuild` succeeds for supported destination. |

Minimum focused test commands:

```sh
swift test --filter TTFXSwiftUITests
swift test --filter TTFXGalleryAppTests
swift test
xcodebuild -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build
xcodebuild -scheme TTFXGalleryApp -destination 'generic/platform=iOS Simulator' build
```

If the app is not representable as a pure SwiftPM app target, document the required Xcode project/workspace and replace the SwiftPM app test command with the appropriate Xcode test command.

## Functional requirements

### Gallery

- The app must show all 37 effects from `EffectRegistry.names`.
- The first launch must select a deterministic default effect.
- Each effect row must show name, sample text, seed, and canvas size.

### Preview

- The preview must render a live frame sequence from native Swift effects.
- Play, pause, reset, and effect switching must be deterministic for a fixed seed.
- The renderer must not call Rust, the Swift CLI, or read parity fixtures in production.

### Controls

- Users can edit input text.
- Users can change seed.
- Users can change canvas width and height within safe bounds.
- Users can select an effect from the full registry.
- Users can start, pause, and reset playback.

### Renderer

- Use `TTFXSwiftUI` renderer/snapshot types as the primary app rendering seam.
- Use Metal when available.
- Fall back to non-Metal SwiftUI frame rendering when Metal is unavailable.
- Expose enough state for deterministic tests without requiring a real drawable.

### Accessibility

- Root view has a clear app title.
- Effect picker and playback controls have accessibility labels.
- Preview exposes visible text or a meaningful summary for assistive technologies.

## Acceptance criteria

- [ ] OpenSpec change exists and validates.
- [ ] App target builds locally.
- [ ] App opens from Xcode as a standalone GUI app.
- [ ] Gallery lists all 37 effects.
- [ ] At least one effect animates from native Swift state in the GUI.
- [ ] Play/pause/reset are covered by tests.
- [ ] App production code contains no Rust subprocess, CLI subprocess, fixture playback, or frame-dump table fallback.
- [ ] Focused GUI tests pass.
- [ ] Existing `swift test` passes.
- [ ] Supported Xcode build destinations pass.
- [ ] README/docs explain how to open and run the app.

## Review plan

Review in this order:

1. OpenSpec proposal/design/tasks/spec.
2. Package/app target wiring.
3. TDD tests and RED/GREEN evidence.
4. App state model and renderer integration.
5. SwiftUI views and accessibility.
6. Xcode build and manual launch evidence.

## Suggested work units

| Unit | Scope | Validation |
|---|---|---|
| 1 | SDD artifacts and target decision | OpenSpec validation / reviewer approval. |
| 2 | App target and import smoke | App target builds; import tests pass. |
| 3 | Gallery state model | 37-effect gallery tests pass. |
| 4 | Renderer view model | deterministic play/pause/reset tests pass. |
| 5 | SwiftUI root UI | UI smoke/accessibility tests pass. |
| 6 | Metal/fallback integration | headless renderer tests and Xcode build pass. |
| 7 | Docs and manual run | README commands verified. |

## Risks

| Risk | Mitigation |
|---|---|
| SwiftPM app target limitations | Decide early whether an Xcode project is required. |
| Metal is hard to test headlessly | Test upload/command plans; document manual visual validation separately. |
| App work bloats library APIs | Add reusable library seams only after RED tests prove the need. |
| Effect-specific options explode scope | Start with common seed/text/canvas controls; defer per-effect option editors unless explicitly accepted. |

## Done definition

The standalone GUI app is done when a reviewer can clone the repository, open the documented app target in Xcode, press Run, see the native Swift TTFX gallery, select effects, and watch a deterministic native Swift animation without any Rust or CLI subprocess in production app code.
