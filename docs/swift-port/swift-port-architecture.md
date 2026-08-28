# Swift port architecture guide

This guide explains how the native Swift port maps to the original Rust implementation, how frames flow through the library, and where to look when you need to change or debug an effect. It is written for experienced programmers who want a working mental model of the codebase rather than an API tour.

## Quick path

1. Start with the original Rust runtime in `src/engine/` and `src/effects/`.
2. Compare the Swift core in `Sources/ttfx-swift/Core/` and effect implementations in `Sources/ttfx-swift/Effects/`.
3. Use the parity tests in `tests/ttfx-effectsTests/` and `tests/ttfx-cliTests/` to understand what must stay byte-compatible.
4. Use `Sources/ttfx-swift/SwiftUI/` and `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/` only after you understand `Canvas`, `Frame`, and `Effect.tick(into:)`.

## Original implementation reference

The Swift port is a native implementation of the Rust library in this repository, not a wrapper around it.

| Concern | Original Rust | Swift port |
|---|---|---|
| Package entry | `src/lib.rs`, `src/main.rs` | `Package.swift` |
| CLI | `src/cli.rs` | `Sources/ttfx-swift/CLI/TTFXCLI.swift` |
| Runtime loop | `src/engine/effect.rs` | `Sources/ttfx-swift/Core/EffectRuntime.swift`, `RuntimeExecution.swift`, `EffectEngine.swift` |
| Canvas/input/frame model | `src/engine/canvas.rs`, `input.rs`, `terminal.rs` | `Sources/ttfx-swift/Core/TTFXCore.swift`, `TTFXANSI.swift` |
| Effects registry | `src/effects/mod.rs` | `Sources/ttfx-swift/Effects/TTFXEffects.swift` |
| Effect implementations | `src/effects/*.rs` | `Sources/ttfx-swift/Effects/*Effect.swift` |
| Utility primitives | `src/utils/*` | `Sources/ttfx-swift/Core/ParityPrimitives.swift` |
| Swift UI surface | none | `Sources/ttfx-swift/SwiftUI/*` |
| Standalone GUI app | none | `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/*` |

The most important relationship is this: Rust owns the original behavior and terminal semantics; Swift owns a deterministic, native model that is continuously checked against Rust with parity tests and fixtures.

## Package shape

`Package.swift` splits the Swift code into focused products and targets. `ttfx-swift` is the library product; `TTFXCore`, `TTFXEffects`, and `TTFXSwiftUI` are the main targets behind that product.

| Product / target | Role |
|---|---|
| `ttfx-swift` library product | Public package library that exposes the Swift port modules. |
| `TTFXCore` target | Core canvas, frame, input, runtime, ANSI, parity primitives, and scheduling abstractions. |
| `TTFXEffects` target | The 37 native Swift effect implementations and their registry. |
| `TTFXSwiftUI` target | Frame snapshots, SwiftUI text rendering, deterministic renderer scheduling, and Metal planning seams. |
| `ttfx` executable | Swift CLI surface and parity dump entrypoint. |
| `TTFXGalleryApp` executable | SwiftUI app for previewing effects without shelling out to CLI/Rust. |

This layering matters. Effects depend on core primitives. SwiftUI depends on core snapshots/effects. The GUI app depends on the library; it should not become the place where effect behavior is implemented.

## Core model: `Canvas`, `InputText`, `Frame`, `Effect`

The Swift minimum model lives in `Sources/ttfx-swift/Core/TTFXCore.swift`.

```swift
public struct Canvas { ... }
public struct InputText { ... }
public struct Frame { ... }
public protocol Effect {
    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64)
    mutating func tick(into frame: inout Frame) -> TickStatus
}
```

### `Canvas`

`Canvas` is the immutable terminal-sized coordinate space. Its dimensions are validated at construction. `Canvas.ingest(_:)` converts a Swift `String` into `InputText` by splitting Unicode scalars into positioned characters.

Important difference from Rust: Rust input preprocessing in `src/engine/input.rs` understands richer terminal/ANSI behavior. Swift `Canvas.ingest(_:)` is intentionally simpler: it positions Unicode scalars and does not implement the full original terminal preprocessor.

### `InputText`

`InputText` stores two parallel contiguous arrays:

- `scalars`: Unicode scalar values.
- `positions`: 1-based terminal positions for each scalar.

Rows are assigned from top input line to higher visual rows so frame output can render top-down later.

### `Frame`

`Frame` is the mutable cell buffer that effects draw into. It stores:

- `columns`
- `rows`
- `cells: ContiguousArray<Cell>`

Coordinates are 1-based: `frame[column: 1, row: 1]` is valid. Internally, offsets are row-inverted:

```swift
return (rows - row) * columns + (column - 1)
```

That means row `1` is the visual bottom row in the coordinate model, while snapshot/rendering code can still iterate in top-to-bottom visual order. This convention is a common source of off-by-one and upside-down bugs.

### `Effect`

Swift effects are stateful value types or structs conforming to `Effect`. Each call to `tick(into:)` mutates the effect and writes the next visual state into the provided frame. The return value is either:

- `.running`
- `.complete`

This is the Swift equivalent of Rust's `Effect::build()` plus repeated `next_frame()` calls in `src/engine/effect.rs`, but with a different shape: Swift writes into a reusable `Frame` instead of returning a terminal string per frame.

## Runtime data flow

### Rust CLI flow

```text
stdin / input file
  ↓
src/main.rs
  ↓
src/cli.rs parses Clap subcommands/options
  ↓
EngineCtx + TerminalConfig
  ↓
src/effects/mod.rs builds Box<dyn Effect>
  ↓
effect.build(ctx)
  ↓
loop effect.next_frame(ctx)
  ↓
terminal.print_frame(...)
```

`src/engine/effect.rs` contains the production run loop. It handles build, terminal preparation, frame streaming, stop signals, terminal resize behavior, cursor restoration, and parity dump mode.

### Swift CLI flow

```text
stdin / input file
  ↓
TTFXCLI.run(...)
  ↓
Canvas + Canvas.ingest(text)
  ↓
EffectRegistry.makeEffect(named: ...)
  ↓
Frame allocation
  ↓
effect.tick(into: &frame)
  ↓
terminal bytes or parity dump frames
```

The Swift CLI is useful for native parity and basic rendering, but it is not a full replacement for the Rust CLI. The Rust CLI exposes typed Clap subcommands and terminal streaming behavior. The Swift CLI currently takes a simpler effect-name-oriented path. In non-parity terminal mode, Swift currently renders the completed/final frame rather than streaming every intermediate frame.

### SwiftUI / app flow

```text
TTFXGalleryRootView controls
  ↓
TTFXGalleryViewModel
  ↓
EffectFrameBox creates Canvas + InputText + Effect
  ↓
TTFXDeterministicRenderer throttles ticks by Duration
  ↓
TTFXFrameSnapshot
  ↓
TTFXGalleryVisiblePreview / TTFXFrameView / Metal planning seams
```

The app code in `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/` must stay native. It must not shell out to Rust, invoke the Swift CLI, read parity fixtures, or use frame-dump fallbacks for production preview behavior.

## Effect registry

Rust uses a Clap enum in `src/effects/mod.rs`:

```rust
pub enum EffectCommand {
    Beams(beams::BeamsConfig),
    ...
}
```

Each variant owns its typed config and `build_effect()` returns `Box<dyn Effect>`.

Swift uses a string registry in `Sources/ttfx-swift/Effects/TTFXEffects.swift`:

```swift
public enum EffectRegistry {
    public static let names: [String] = [...]
    public static func makeEffect(named: String, ...) -> (any Effect)?
}
```

The Swift registry currently includes all 37 native effects:

```text
beams, binarypath, blackhole, bouncyballs, bubbles, burn,
colorshift, crumble, decrypt, errorcorrect, expand, fireworks,
highlight, laseretch, matrix, middleout, orbittingvolley,
overflow, pour, print, rain, randomsequence, rings, scattered,
slice, slide, smoke, spotlights, spray, swarm, sweep,
synthgrid, thunderstorm, unstable, vhstape, waves, wipe
```

When adding or changing an effect, update the Swift registry and compare against the Rust variant in `src/effects/mod.rs`. Do not assume alphabetical order is cosmetic; tests and UI selectors rely on stable registry order.

## How individual effects are ported

Most effects follow this pattern:

1. Read the Rust source in `src/effects/<effect>.rs`.
2. Preserve its timing constants, ordering quirks, seeded randomness, and coordinate assumptions.
3. Build a Swift `Configuration` and effect state.
4. Implement `tick(into:)` to clear/write a `Frame` deterministically.
5. Add or maintain parity coverage.

There are two broad implementation styles in Swift:

| Style | Description | Example paths |
|---|---|---|
| Direct state machine | Effect stores its own counters, particles, groups, or scheduling data and writes frames directly. | `PrintEffect.swift`, `SlideEffect.swift`, `BubblesEffect.swift` |
| Runtime composition | Effect uses shared animation/motion/scene primitives from core. | `AnimationSubstrate.swift`, `MotionComposition.swift`, `SceneComposition.swift`, `RuntimeActions.swift` |

Prefer direct ports when the Rust implementation has effect-specific quirks. Prefer shared runtime composition when behavior is genuinely common and parity remains demonstrable.

## Parity primitives

`Sources/ttfx-swift/Core/ParityPrimitives.swift` is where many cross-language compatibility details live. It mirrors behavior that would otherwise diverge naturally between Rust/Python/Swift ecosystems:

- seeded RNG behavior;
- geometry helpers;
- color and gradient handling;
- Python-compatibility helpers where ported behavior originally depended on Python semantics;
- ordering and interpolation utilities.

Treat this file as compatibility infrastructure, not as random utilities. Small changes can affect many effects at once.

## Testing and parity strategy

The port is guarded by complementary test areas.

| Test type | Paths | What it proves |
|---|---|---|
| Core/unit tests | `tests/ttfx-swiftTests/` | Swift primitives behave predictably. |
| Effect parity tests | `tests/ttfx-effectsTests/` | Swift effect frames match admitted Rust behavior. |
| CLI parity tests | `tests/ttfx-cliTests/` | Swift parity-dump output can be compared to Rust output. |
| SwiftUI renderer tests | `tests/ttfx-swiftUITests/` | Snapshot rendering, deterministic scheduling, and renderer/Metal planning seams behave without an app launch. |
| GUI/app tests | `tests/TTFXGalleryAppTests/` | The standalone SwiftUI app state and rendering seams behave without launching a GUI. |

Important fixture paths:

- `tests/fixtures/effects/manifest.json`
- `tests/fixtures/effects/*.frames`
- `tools/swift-parity/generate-effect-oracles.sh`

The effect oracle manifest records an admitted Rust revision and generated frame dumps. Those dumps are not production app data; they are test oracles.

### Parity mode versus production mode

Rust has `dump_effect()` in `src/engine/effect.rs` to write length-prefixed frames. Swift has parity harness support under `Sources/ttfx-swift/Core/ParityHarness.swift` and CLI parity behavior. That machinery exists for tests.

Do not route user-facing GUI rendering through parity dumps. If the GUI needs a frame, it should instantiate native Swift effects and tick them directly.

## SwiftUI and the standalone app

The library SwiftUI layer lives in `Sources/ttfx-swift/SwiftUI/`:

| File | Role |
|---|---|
| `FrameSnapshot.swift` | Converts `Frame` data into renderable snapshot/cell structures. |
| `Renderer.swift` | Deterministic renderer scheduling plus Metal upload/command planning seams. |
| `Views.swift` | Reusable SwiftUI frame/gallery/status views. |
| `Gallery.swift` | Built-in gallery demo definitions. |
| `TTFXSwiftUI.swift` | Module-level export surface. |

The app layer lives in `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/`:

| File | Role |
|---|---|
| `TTFXGalleryApp.swift` | `@main` app entrypoint. |
| `TTFXGalleryRootView.swift` | Controls, preview layout, accessibility labels, and visible preview fallback. |
| `TTFXGalleryViewModel.swift` | Selected effect, sample text, seed, canvas, playback, looping, FPS, font size, renderer state. |

Current rendering caveat: `TTFXGalleryPreviewRendererSelection.resolve(...)` intentionally resolves to `.swiftUIFrameView`. The Metal path has planning/upload seams, but drawable-backed glyph rendering is deferred until it has real validation.

## Known behavioral gaps versus Rust

This is the section to read before claiming feature parity.

| Area | Current Swift state |
|---|---|
| Terminal streaming | Rust streams every frame and manages cursor/resize behavior. Swift CLI is simpler and does not fully mirror the production terminal loop. |
| Per-effect CLI options | Rust exposes typed Clap configs per effect. Swift CLI mostly accepts effect names and default construction. |
| Input preprocessing | Rust preprocesses ANSI/cursor/tab/color behavior. Swift `Canvas.ingest(_:)` positions Unicode scalars only. |
| Random effect selection | Swift CLI random behavior is limited; parity mode follows deterministic candidates. |
| Metal rendering | SwiftUI app currently uses visible SwiftUI fallback; Metal drawable-backed text rendering is not the default. |
| Fixture scope | Fixture oracles are intentionally bounded and used for tests, not runtime. |

These gaps are not failures by themselves. They are boundaries of the current port.

## Change checklist

Use this when modifying the Swift port:

- [ ] Identify the original Rust source path for the behavior.
- [ ] Decide whether the change belongs in `TTFXCore`, `TTFXEffects`, `TTFXSwiftUI`, CLI, or app.
- [ ] Preserve deterministic seed behavior.
- [ ] Check coordinate direction and 1-based indexing.
- [ ] Add or update focused Swift tests first.
- [ ] Add or update parity tests if behavior is expected to mirror Rust.
- [ ] Do not use Rust/CLI subprocesses from production SwiftUI app code.
- [ ] Run the narrow test command for the changed layer.
- [ ] Run broader Swift/OpenSpec/Xcode validation when packaging or app behavior changes.

## Useful commands

```sh
# Focused app tests
swift test --filter TTFXGalleryAppTests

# Full Swift package tests, serial when timing-sensitive tests are noisy
swift test --no-parallel

# Build the standalone app product
swift build --product TTFXGalleryApp

# Validate the GUI OpenSpec change
openspec validate standalone-swift-gui-app --strict

# Regenerate and build the Xcode app bundle
xcodegen generate
xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'generic/platform=macOS' build
```

## Where to start reading

For a first deep read, use this order:

1. `Sources/ttfx-swift/Core/TTFXCore.swift`
2. `src/engine/effect.rs`
3. `Sources/ttfx-swift/Effects/TTFXEffects.swift`
4. One simple effect pair: `src/effects/print_effect.rs` and `Sources/ttfx-swift/Effects/PrintEffect.swift`
5. One motion-heavy pair: `src/effects/slide.rs` and `Sources/ttfx-swift/Effects/SlideEffect.swift`
6. `Sources/ttfx-swift/Core/ParityPrimitives.swift`
7. `tests/ttfx-effectsTests/EffectFrameParityTests.swift`
8. `Sources/ttfx-swift/SwiftUI/Renderer.swift`
9. `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/TTFXGalleryViewModel.swift`
10. `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/TTFXGalleryRootView.swift`

That path moves from data model, to original runtime, to registry, to concrete behavior, to parity guarantees, and finally to UI presentation.
