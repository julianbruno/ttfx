# Native Swift port status

The native Swift port is a SwiftPM implementation that runs in parallel with the Rust `ttfx` binary. It is not a replacement for the Rust product described in the root README; the Rust implementation remains the production authority and the reference oracle for Swift parity checks.

## Quick path

Run these commands from the repository root:

```sh
swift package resolve
swift build --product ttfx
printf 'Swift\nTTE' | swift run ttfx -- --canvas-width 12 --canvas-height 6 print
printf 'Swift\nTTE' | swift run ttfx -- --canvas-width 12 --canvas-height 6 print --print-speed 5
swift run ttfx -- print --help
swift run ttfx -- --print-completion bash
swift run ttfx -- --print-completion zsh
```

This toolchain’s `swift run` takes the executable name (`swift run ttfx`), not `--product`. Use `swift build --product ttfx` when you need to name the product at build time.

Per-effect TTE/Rust flags go **after** the effect name. `ttfx <effect> --help` lists that effect’s flags. Unknown effect flags are rejected. The live path writes every animation frame (not only the last one).

### Gallery app (macOS and iOS Simulator)

```sh
xcodegen generate
open TTFXGalleryApp.xcodeproj
```

1. Scheme **TTFXGalleryApp** (product `TTFXGalleryApp.app`, bundle id `codes.suscodigos.ttfx.gallery`).
2. Destination **My Mac** or an **iPhone Simulator**.
3. Run.

Do not Run the SwiftPM `TTFXGalleryApp` executable. That binary has no `CFBundleIdentifier`. On iOS, UIKit traps in `BKSHIDEvent`. On Mac, Console shows `missing main bundle identifier` and `connection to service named com.apple.linkd.autoShortcut`.

## What is implemented

| Proposal area | Verified implementation state |
|---|---|
| Core engine | `TTFXCore` provides frames/canvas/input, deterministic effect initialization, Xoshiro-compatible primitives, motion/scene/runtime composition, ANSI frame rendering helpers, and parity diagnostics. |
| Effects | `TTFXEffects` registers all 37 TTE/Rust effect names. Each effect has a typed configuration with TTE flag names and defaults; `print` is no longer hardcoded speed/easing/gradient constants. |
| CLI | `TTFXCLI` parses Rust-style terminal options, TTE per-effect flags after the effect name, seed, input file, random-effect filters, hidden `--parity-dump`/`--max-frames`, and bash/zsh completions. Live output emits each animation frame; hidden parity-dump emits length-prefixed frames for oracle comparison. |
| SwiftUI/Metal | Optional `TTFXSwiftUI` exposes frame snapshots, a deterministic 37-effect gallery model/view, scheduler, Metal availability, upload plans, command plans, and an `MTKView` bridge. `TTFXGalleryApp.xcodeproj` is the iOS/macOS `.app` launch path. |
| Rust scope | The Rust code and README product claims remain unchanged. Swift uses Rust as an oracle in tests; production Swift effect execution does not shell out to Rust. |

## Evidence map

| Criterion | Evidence recorded or inspectable |
|---|---|
| 37 Swift effects | `Sources/ttfx-swift/Effects/TTFXEffects.swift` lists all 37 names and factory mappings. `openspec/changes/native-swift-port/apply-progress.md` records the 37-effect `EffectFrameParityTests` gate. |
| Focused CLI byte parity | `tests/ttfx-cliTests/CLIParityDumpTests.swift` compares Swift CLI `--parity-dump` stdout byte-for-byte with live Rust for `print`, `wipe`, and `expand`. |
| 37-effect CLI smoke | The same CLI parity test decodes one nonempty length-prefixed parity frame for every Rust effect name. This is smoke coverage, not full-stream byte parity for all effects. |
| Completions/help | `tests/ttfx-cliTests/CLIParsingTests.swift` covers public global options, all 37 effect names, per-effect flags after the effect name, unknown-flag rejection, bash/zsh completion shape, hidden parity flags, and `ttfx print --help`. |
| Per-effect ajustes | `PrintEffect.Configuration` and CLI leftover-token parsing apply TTE/Rust flags. Frame-difference tests cover `print` (`--print-speed`), `rain` (`--rain-colors` / `--movement-speed`), and `wipe` (`--wipe-direction`). Task list: [tte-ajustes-tareas.md](tte-ajustes-tareas.md). |
| SwiftUI/gallery | `tests/ttfx-swiftUITests/RendererTests.swift` covers snapshot ordering, 37-effect gallery contents, scheduler cadence/capacity, Metal availability, upload packing, and command planning. `galleryXcodeAppDeclaresBundleIdentifierAndIOSDestinations` asserts the Xcode app has bundle id `codes.suscodigos.ttfx.gallery` and iOS destinations. |
| Proposal/task state | `openspec/changes/native-swift-port/tasks.md` is the task ledger. Phase 5.4 records README/proposal verification only; final matrix and package/CI/bin-test docs remain separate Phase 5 tasks unless their boxes are explicitly checked. |

## Current limitations

- Full CLI byte parity is focused, not exhaustive: live Rust byte equality is asserted for `print`, `wipe`, and `expand`, while all 37 effects have CLI parity-dump smoke coverage.
- Every TTE per-effect flag is accepted with the TTE/Rust default; changing a setting is proven to change frames for `print`, `rain`, and `wipe`. Other effects store and parse the matching fields; not every flag is proven to change pixels yet.
- The SwiftUI/Metal work is testable headlessly through deterministic upload and command plans, but it does not prove visual GPU presentation in a drawable-backed app window. Plan to wire a real Metal preview: [metal-preview-plan.md](metal-preview-plan.md).
- The Swift core keeps a fixed-capacity/performance proxy; it does not claim measured zero heap allocations from an allocation counter.
- Linux/Windows support remains out of initial Swift scope.
- Python-style plugins and behavioral improvements over Rust/upstream quirks remain out of scope.

## Validation commands

Use focused checks first:

```sh
swift test --filter EffectFrameParityTests
swift test --filter CLIParityDumpTests
swift test --filter CLIParsingTests
swift test --filter TTFXSwiftUITests
swift test --filter galleryXcodeAppDeclaresBundleIdentifierAndIOSDestinations
swift test
```

Documentation-only checks can use:

```sh
git diff --check
```

Do not run the live Rust-backed parity tests concurrently; several suites intentionally serialize oracle subprocess work.

## CI and top-level validation

The top-level `./bin/test` entrypoint now includes Swift validation alongside the existing Rust checks. It requires `cargo`, `python3`, and `swift`; it preserves Linux/glibc-only Rust parity and resize behavior while running Swift package validation in a split that avoids concurrent live-Rust oracle pressure.

Useful local commands:

```sh
sh -n bin/test
swift test --filter EffectFrameParityTests
swift test --skip EffectFrameParityTests
swift build --product ttfx
swift run --skip-build ttfx -- print --help
```

On Linux CI the Swift path builds the CLI and checks help output; SwiftUI/Metal tests are macOS-oriented because they depend on Apple frameworks.

See [Swift Package Integration](spm.md) for product-level integration details.
