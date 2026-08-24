# Apply Progress: standalone-swift-gui-app

## Implemented scope

- Added SwiftPM-first executable product/target `TTFXGalleryApp` using native `TTFXCore`, `TTFXEffects`, and `TTFXSwiftUI` dependencies.
- Kept app source under the approved SwiftUI edit surface at `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/` and excluded it from the `TTFXSwiftUI` library target.
- Added headless-testable `TTFXGalleryViewModel` exposing all 37 `EffectRegistry.names` in registry order with deterministic default selection.
- Added editable text, seed, selected effect, clamped canvas bounds, frame-rate state, play/pause/reset, frame advancement, renderer status, and preview summary state.
- Connected app rendering to native Swift effect state through `TTFXDeterministicRenderer` and `TTFXFrameSnapshot`.
- Added minimal SwiftUI root view with title, effect picker, text/seed/canvas/frame-rate controls, play/reset/advance controls, automatically ticking preview while playing, renderer status, and accessibility labels.
- Added a production-code prohibition scan for app source.
- Added README build/open instructions and documented iOS Simulator deferral.
- Made `TTFXMetalRendererAvailability` explicitly constructible so headless fallback status can be injected in tests.
- Wired preview selection through a headless-testable seam: platform-supported Metal availability selects `TTFXMetalFrameView`; unavailable/unsupported paths select `TTFXFrameView` fallback.
- Renamed the CLI entrypoint source from `Sources/ttfx-swift/CLI/main.swift` to `Sources/ttfx-swift/CLI/TTFXCLI.swift` so Xcode does not treat the `@main` CLI type as conflicting with implicit top-level `main.swift` semantics.
- Added an XcodeGen fallback project (`project.yml` generating `TTFXGalleryApp.xcodeproj`) that builds a real macOS `.app` bundle with bundle identifier `codes.suscodigos.ttfx.gallery`.
- Deferred drawable-backed Metal preview from the app default because the current `TTFXMetalFrameView` upload-plan seam does not draw visible glyphs yet; the app now uses the visible `TTFXFrameView` fallback while keeping Metal planning/status test coverage.
- Enlarged the preview region with a 340-point minimum height and changed the default sample text from `Swift\nTTFX` to `TTFX` so the launch screen no longer displays "Swift" in the editable sample.
- Enlarged the preview contract to expose a minimum 200-point width and height, added configurable/clamped preview font-size state wired into an app-local visible SwiftUI preview, changed the default sample text to `Hello` so launch is visible without saying `Swift` or `TTFX`, and added loop playback state/control with a deterministic frame-budget seam.
- Updated the app-local visible preview to display the text-field content directly when present, while retaining snapshot fallback for empty input.
- Moved controls into a fixed-width `Controls` sidebar beside the preview so the effect picker remains visible instead of being lost above the larger preview area.
- Made the visible preview prefer rendered effect snapshot lines whenever the selected effect produces non-blank output, falling back to the text-field content only for blank frames so effect selection/playback can visibly change the preview.

## Strict TDD evidence

### RED

- `swift test --filter TTFXGalleryAppTests` exited 1 after adding the test target/tests and before app wiring:
  - `product 'TTFXGalleryApp' required by package 'ttfx' target 'TTFXGalleryAppTests' not found.`
- `swift test --filter TTFXGalleryAppTests` exited 1 after adding frame-rate and Metal/fallback selection tests:
  - `TTFXGalleryViewModel` had no `framesPerSecond`, `frameIntervalMilliseconds`, or `setFramesPerSecond` seam.
  - `TTFXGalleryPreviewRendererSelection` was not defined.
- After initial implementation, the focused suite still exited 1 and exposed test-proven gaps:
  - `TTFXMetalRendererAvailability` initializer was inaccessible for headless fallback injection.
  - Prohibition scan caught an over-broad `ttfx ` token against the app title.
  - Effect-switch snapshot inequality was not a valid deterministic assertion because initial frames can be blank.

### GREEN

- `swift test --filter TTFXGalleryAppTests` exited 0 with 6 tests passing after the minimal app target, view model, view, renderer seam injection, scan refinement, and preview summary were implemented.
- `swift test --filter TTFXGalleryAppTests` exited 0 with 8 tests passing after frame-rate controls, preview selection seam, Metal-gated preview, and automatic play ticking were implemented.
- `swift build --product TTFXGalleryApp` exited 0.

### TRIANGULATE / REFACTOR

- Added alternate/negative coverage for clamped invalid canvas sizes, paused advancement, reset determinism, seed/effect reinitialization via preview summary, frame-rate clamping/intervals, Metal available/unavailable/platform-unsupported preview selection, headless fallback renderer status, accessibility labels, and forbidden production tokens.
- Refactor was limited to keeping app-specific state in the app target and exposing only the smallest reusable `TTFXMetalRendererAvailability` initializer required by tests.

## Commands run

- `swift test --filter TTFXGalleryAppTests` — exit 1 (RED: missing `TTFXGalleryApp` product/target).
- `swift test --filter TTFXGalleryAppTests` — exit 1 (implementation gaps listed above).
- `swift test --filter TTFXGalleryAppTests` — exit 0 (6 tests passed).
- `swift build --product TTFXGalleryApp` — exit 0.
- `swift test --filter TTFXGalleryAppTests` — exit 1 (RED: missing frame-rate and preview selection APIs).
- `swift test --filter TTFXGalleryAppTests` — exit 0 (8 tests passed).
- `swift build --product TTFXGalleryApp` — exit 0.
- `swift test` — exit 1; all new app tests passed, but existing `preallocatedEngineMaintainsFrameStorageAcrossFiveHundredTicks` failed its performance threshold with `medianNanoseconds` 1959307 not less than 1000000 under concurrent execution.
- `swift test --filter preallocatedEngineMaintainsFrameStorageAcrossFiveHundredTicks` — exit 0, confirming the performance test passes in isolation.
- `swift test --no-parallel` — exit 0, 154 tests passed; this is the stable full Swift suite command for this evidence because the performance threshold is concurrency-sensitive.
- `openspec validate standalone-swift-gui-app --strict` — exit 0.
- `xcodebuild -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0.
- `xcodebuild -scheme TTFXGalleryApp -destination 'generic/platform=iOS Simulator' build` — exit 0.
- `xcodebuild -scheme ttfx -destination 'generic/platform=macOS' build` — exit 0 after renaming the CLI entrypoint source away from `main.swift`.
- `swift build --product ttfx` — exit 0 after the CLI entrypoint rename.
- Direct launch smoke: running the built `TTFXGalleryApp` binary stayed alive for 3 seconds before the harness terminated it, confirming it no longer exits immediately in this environment.
- `xcodegen generate` — exit 0, generated `TTFXGalleryApp.xcodeproj`.
- `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0 and produced `TTFXGalleryApp.app`.
- `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' -showBuildSettings` confirmed `FULL_PRODUCT_NAME = TTFXGalleryApp.app`, `WRAPPER_EXTENSION = app`, and `PRODUCT_BUNDLE_IDENTIFIER = codes.suscodigos.ttfx.gallery`.
- RED after user launch feedback: `swift test --filter TTFXGalleryAppTests` failed when the app was expected to prefer visible SwiftUI fallback even with Metal available; current behavior selected `.metalFrameView`.
- GREEN after display fix: `swift test --filter TTFXGalleryAppTests` — exit 0, 8 tests passed; `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0.
- Direct `.app` launch smoke: opened the built `TTFXGalleryApp.app`; `CFBundleIdentifier` resolved to `codes.suscodigos.ttfx.gallery`, and the app process stayed alive after 3 seconds.
- RED after user preview feedback: `swift test --filter TTFXGalleryAppTests` failed because `TTFXGalleryRootView.previewMinimumHeight` did not exist while tests required a larger preview area and default sample text without "Swift".
- GREEN after preview UX fix: `swift test --filter TTFXGalleryAppTests` — exit 0, 9 tests passed; `swift build --product TTFXGalleryApp` — exit 0; `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0.
- RED after next preview UX request: `swift test --filter TTFXGalleryAppTests` exited 1 because `TTFXGalleryRootView.previewMinimumWidth`, preview font-size state/APIs, loop state/APIs, and `loopFrameBudget` initialization did not exist.
- GREEN after next preview UX fix: `swift test --filter TTFXGalleryAppTests` — exit 0, 11 tests passed.
- RED after blank-launch feedback: focused app tests failed when the expected visible default text was `Hello` but the model still defaulted to an empty string.
- GREEN after visible-default fix: `swift test --filter TTFXGalleryAppTests` — exit 0, 11 tests passed; `swift build --product TTFXGalleryApp` — exit 0; `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0.
- RED after effect-selector feedback: `swift test --filter TTFXGalleryAppTests` exited 1 because the root view had no `controlsMinimumWidth` contract for a visible controls sidebar.
- GREEN after selector layout fix: `swift test --filter TTFXGalleryAppTests` — exit 0, 12 tests passed; `swift build --product TTFXGalleryApp` — exit 0; `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0.
- RED after dynamic-preview feedback: focused tests failed because the visible preview had no public rendered-line selection seam and always showed literal text-field content.
- GREEN after dynamic-preview fix: `swift test --filter TTFXGalleryAppTests` — exit 0, 14 tests passed; `swift build --product TTFXGalleryApp` — exit 0; `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build` — exit 0.
- Changed-line budget check: changed/new files are approximately 1125 lines plus small tracked diffs and generated Xcode project metadata, below the 6000-line single-PR budget.

## Remaining tasks

- Manual user confirmation of a successful Xcode Run from `TTFXGalleryApp.xcodeproj` is still pending.
