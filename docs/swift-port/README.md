# Native Swift port status

**Swift implements all 37 Rust effect counterparts, with sampled full-run parity verified against Rust.** It remains a work in progress, not a replacement for the production Rust binary. This is a port of a port: Python TerminalTextEffects → Rust `ttfx` → native Swift. Rust remains the local reference oracle; production Swift effects do not launch Rust.

[![Decrypt: Rust left, Swift Metal right](comparisons/decrypt-preview.gif)](comparisons/decrypt.mp4)

Six-second excerpt of real captured output at its original speed. [Full decrypt video](comparisons/decrypt.mp4) · [All 37 Rust/Metal videos and reproduction](comparisons/README.md). Videos illustrate the recorded sample, not universal parity.

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

### Video comparison (macOS)

```sh
./tools/video-comparison/capture.sh
./script/build_and_run.sh --compare
```

The app compares **Rust terminal**, **Swift Metal**, optional **Swift CLI**, and optional **SwiftUI** recordings. The CLI pane comes from the actual pure-Swift executable, not a relabeled GUI renderer. Search the effect sidebar; use independent native pane toggles, shared playback/scrubbing, and **Speed** from 0.5× to 3× (default 1×).

**Loop** defaults off. When enabled, all present tracks restart together at the longest track's endpoint, retaining the selected speed; shorter tracks hold their final frame until that boundary. Hidden tracks remain synchronized. Ping-pong playback and easing/timing selection are not implemented.

Generated libraries stay in the ignored `artifacts/video-comparison/` directory. The curated 37 side-by-side MP4s linked above are tracked documentation assets. See [comparison guide](video-comparison.md), [capture pipeline](video-recording.md), and [observed TDD/regression evidence](video-comparison-tdd.md).

## What is implemented

| Proposal area | Verified implementation state |
|---|---|
| Core engine | `TTFXCore` provides frames/canvas/input, deterministic effect initialization, Xoshiro-compatible primitives, motion/scene/runtime composition, ANSI frame rendering helpers, and parity diagnostics. |
| Effects | `TTFXEffects` registers all 37 TTE/Rust effect names. Each effect has a typed configuration with TTE flag names and defaults; `print` is no longer hardcoded speed/easing/gradient constants. |
| CLI | `TTFXCLI` parses Rust-style terminal options, TTE per-effect flags after the effect name, seed, input file, random-effect filters, hidden `--parity-dump`/`--max-frames`, and bash/zsh completions. Live output emits each animation frame; hidden parity-dump emits length-prefixed frames for oracle comparison. |
| SwiftUI/Metal | Optional `TTFXSwiftUI` exposes frame snapshots, a deterministic 37-effect gallery model/view, scheduler, and a drawable-backed `MTKView` Metal renderer with glyph atlas and production shaders. The gallery uses Metal when available; **Use Metal** selects the SwiftUI fallback without restarting the effect. `TTFXGalleryApp.xcodeproj` is the iOS/macOS `.app` launch path. |
| Comparison tooling | `TTFXVideoCapture` records four tracks; `TTFXComparisonApp` provides searchable effect selection, optional pane controls, synchronized speed and whole-timeline Loop. Rust subprocesses belong to testing/capture, not production Swift effect execution. |
| Rust scope | Rust remains the production terminal product. Its Python parity and benchmark claims are not Swift claims. |

## Evidence map

| Criterion | Evidence recorded or inspectable |
|---|---|
| 37 Swift effects | `Sources/ttfx-swift/Effects/TTFXEffects.swift` lists all 37 names and factory mappings. `openspec/changes/native-swift-port/apply-progress.md` records the 37-effect `EffectFrameParityTests` gate. |
| Full native-effect runs | `tests/ttfx-effectsTests/CompleteEffectParityTests.swift` compares complete ANSI frame bytes, frame counts, and completion against live Rust: 37 effects × 3 default-config input/seed/canvas cases (111), plus 6 timed cases for `matrix`/`thunderstorm` at 60, 17, and 0 fps. **117/117 parameterized cases passed on macOS on 2026-09-17**, across 2 test functions. |
| Focused CLI byte parity | `tests/ttfx-cliTests/CLIParityDumpTests.swift` compares Swift CLI `--parity-dump` stdout byte-for-byte with live Rust for `print`, `wipe`, and `expand`. |
| Recorded CLI streams | All 37 Rust/Swift CLI dump pairs in the recorded seed-42, 24×8, 25-fps sample matched byte-for-byte. Capture scope and subprocess provenance: [video-recording.md](video-recording.md). The committed CLI smoke test also checks one nonempty frame for each name; it is not an exhaustive CLI corpus. |
| Completions/help | `tests/ttfx-cliTests/CLIParsingTests.swift` covers public global options, all 37 effect names, per-effect flags after the effect name, unknown-flag rejection, bash/zsh completion shape, hidden parity flags, and `ttfx print --help`. |
| Per-effect settings | `PrintEffect.Configuration` and CLI leftover-token parsing apply TTE/Rust flags. Frame-difference tests cover `print` (`--print-speed`), `rain` (`--rain-colors` / `--movement-speed`), and `wipe` (`--wipe-direction`). Task list: [tte-ajustes-tareas.md](tte-ajustes-tareas.md). |
| SwiftUI/gallery | `tests/ttfx-swiftUITests/RendererTests.swift` covers snapshot ordering, 37-effect gallery contents, scheduler cadence/capacity, Metal availability, upload packing, and command planning. `galleryXcodeAppDeclaresBundleIdentifierAndIOSDestinations` asserts the Xcode app has bundle id `codes.suscodigos.ttfx.gallery` and iOS destinations. |
| Visible Metal preview | [metal-preview-plan.md](metal-preview-plan.md) records the implemented renderer, conditional offscreen GPU checks, and local drawable-backed app verification. Headless command-plan tests alone do not establish visible GPU correctness. |
| Playback/UI regressions | [video-comparison-tdd.md](video-comparison-tdd.md) separates observed RED → GREEN → REFACTOR evidence, automated regression checks, and manual UI checks. The final comparison suite recorded 28 passing tests without skips. |
| Proposal/task state | All 27 tasks in `openspec/changes/native-swift-port/tasks.md` are checked. This closes that original task ledger, not the broader [cross-platform CLI specification](cross-platform-cli-spec.md). |

## Current limitations

- The 117 native-effect cases and 37 recorded CLI streams establish sampled parity, not all inputs/configurations. Non-default settings, Unicode/layout/input-ANSI combinations, random-selection RNG continuation, terminal pacing, resize, cancellation, and teardown need broader CLI proof.
- Every TTE per-effect flag is accepted with the TTE/Rust default; changing a setting is proven to change frames for `print`, `rain`, and `wipe`. Other effects store and parse the matching fields; not every flag is proven to change pixels yet.
- Metal presentation has been checked locally in a real app and offscreen GPU tests. That does not certify pixel-exact Rust/Metal parity, every glyph/platform, or drawable-backed presentation in headless CI.
- The Swift core keeps a fixed-capacity/performance proxy; it does not claim measured zero heap allocations from an allocation counter.
- Windows/Linux portability is not certified. The [cross-platform CLI specification](cross-platform-cli-spec.md) and its [pending work ledger](../../odd/tasks/cross-platform-cli.md) cover the portable package graph and terminal lifecycle work still to implement; the current package also contains Apple-framework GUI targets.
- Python-style plugins and behavioral improvements over Rust/upstream quirks remain out of scope.

## Validation commands

Use focused checks first:

```sh
swift test --filter CompleteEffectParityTests
swift test --filter EffectFrameParityTests
swift test --filter CLIParityDumpTests
swift test --filter CLIParsingTests
swift test --filter 'TTFXSwiftUITests|TTFXGalleryAppTests'
swift test --filter TTFXComparisonTests
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

On Linux, `bin/test` requests a Swift CLI build and help check, but this script intent is not evidence that the current mixed CLI/GUI package graph is portable. SwiftUI/Metal and comparison targets depend on Apple frameworks; Windows/Linux validation remains pending.

See [Swift Package Integration](spm.md) for product-level integration details, [architecture](swift-port-architecture.md) for module mapping.
