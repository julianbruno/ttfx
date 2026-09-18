# ttfx

Terminal text effects as a single static binary. Pipe text in, pick an effect.

This repository now carries a three-generation port lineage:

1. **Original:** [TerminalTextEffects](https://github.com/ChrisBuilds/terminaltexteffects) (TTE), the Python project by **ChrisBuilds**.
2. **First port:** `ttfx`, a Rust parity port by **37signals / omacom-io**, built as a dependency-free terminal binary.
3. **Current native port work:** a Swift parity port of the Rust port, developed in this same repository through `TTFXCore`, `TTFXEffects`, `TTFXSwiftUI`, `TTFXGalleryApp`, and the video-comparison tooling.

> [!NOTE]
> **Swift port work in progress.** The Swift code is being built as a parity port of the Rust implementation,
> which is itself a parity port of the original Python TTE project. It does not replace the production Rust
> binary yet. Start with [`docs/swift-port/swift-port-architecture.md`](docs/swift-port/swift-port-architecture.md)
> if you want to understand how the Swift modules map back to the Rust code and, through it, to TTE.

```sh
ls -la | ttfx decrypt
cat banner.txt | ttfx beams
fortune | ttfx --random-effect
git log --oneline -10 | ttfx matrix
```

<img src="docs/effects/decrypt.gif" width="588" alt="the decrypt effect resolving the Omarchy logo">

## Credit where it's due

**The art and behavior begin upstream with [TerminalTextEffects](https://github.com/ChrisBuilds/terminaltexteffects)
(TTE), authored by [ChrisBuilds](https://github.com/ChrisBuilds).** Every effect concept, the animation-engine
shape, and the user-facing CLI vocabulary come from TTE. If you like the effects, star and credit the original
project first.

This repository's Rust `ttfx` implementation is a parity port of TTE, copyrighted by **37signals / omacom-io**
under the same MIT license. It translates the Python engine into a single dependency-free Rust binary while
preserving TTE's frame behavior as closely as possible.

The Swift implementation is a **port of that port**: it maps the Rust engine/effects/CLI and renderer seams into
Swift modules for native apps, SwiftUI/Metal preview, and side-by-side video comparison. The Swift code uses the
Rust binary as its local oracle, and the Rust binary traces back to TTE.

TTE is MIT licensed and so are these ports; the original copyright is preserved in
[LICENSE](LICENSE) and [NOTICE](NOTICE). Please file *effect* ideas upstream, where they belong.

## Why a port

TTE is a Python package. That's the right call for a library, but for a shell toy that lives in
your prompt pipeline it means an interpreter, an install step, and ~65 ms of import before the
first frame. ttfx is one dependency-free binary that starts in half a millisecond.

That difference is the whole reason this exists. On a fullscreen canvas the heavier effects run
out of headroom under Python. Time to render a whole animation, pacing disabled so this measures
throughput rather than `sleep()`:

| At 200×50 cells | frames | ttfx | Python TTE | ttfx fps |
|---|---|---|---|---|
| slide | 375 | 76 ms | 2,203 ms | 4,930 |
| beams | 732 | 181 ms | 5,564 ms | 4,050 |
| rings | 1,566 | 521 ms | 10,439 ms | 3,004 |
| waves | 633 | 374 ms | 8,745 ms | 1,693 |
| startup | — | 0.5 ms | 64 ms | — |

Across the 35 effects that aren't gated on wall-clock time, the median speedup is **27.5×**
(range 17.1×–47.4×). The two that are gated — `matrix` and `thunderstorm` — spend most of their
runtime in a fixed animation duration that no implementation can shorten, so they come in at
1.9× and 1.3×; what ttfx buys there is a far higher frame rate inside that window, not a shorter
one.

Reproduce it with `python3 tools/tests/bench_full.py`, or set `TTFX_BENCH_COLS`, `TTFX_BENCH_LINES`
and `TTFX_BENCH_FILL=1` for the fullscreen numbers above. Both sides run their real user-facing
command, best of five.

## The effects

All 37, each animating the Omarchy logo. Every frame below came out of the Rust binary — and is
byte-identical to what the Python original produces from the same input and seed.

|     |     |
|:---:|:---:|
| <b>beams</b><br><img src="docs/effects/beams.gif" width="400" alt="beams"><br><sub>Create beams which travel over the canvas illuminating the characters behind them</sub> | <b>binarypath</b><br><img src="docs/effects/binarypath.gif" width="400" alt="binarypath"><br><sub>Binary representations of each character move towards the home coordinate of the character</sub> |
| <b>blackhole</b><br><img src="docs/effects/blackhole.gif" width="400" alt="blackhole"><br><sub>Characters are consumed by a black hole and explode outwards</sub> | <b>bouncyballs</b><br><img src="docs/effects/bouncyballs.gif" width="400" alt="bouncyballs"><br><sub>Characters are bouncy balls falling from the top of the canvas</sub> |
| <b>bubbles</b><br><img src="docs/effects/bubbles.gif" width="400" alt="bubbles"><br><sub>Characters are formed into bubbles that float down and pop</sub> | <b>burn</b><br><img src="docs/effects/burn.gif" width="400" alt="burn"><br><sub>Burns vertically in the canvas</sub> |
| <b>colorshift</b><br><img src="docs/effects/colorshift.gif" width="400" alt="colorshift"><br><sub>Display a gradient that shifts colors across the terminal</sub> | <b>crumble</b><br><img src="docs/effects/crumble.gif" width="400" alt="crumble"><br><sub>Characters lose color and crumble into dust, vacuumed up, and reformed</sub> |
| <b>decrypt</b><br><img src="docs/effects/decrypt.gif" width="400" alt="decrypt"><br><sub>Display a movie style decryption effect</sub> | <b>errorcorrect</b><br><img src="docs/effects/errorcorrect.gif" width="400" alt="errorcorrect"><br><sub>Some characters start in the wrong position and are corrected in sequence</sub> |
| <b>expand</b><br><img src="docs/effects/expand.gif" width="400" alt="expand"><br><sub>Expands the text from a single point</sub> | <b>fireworks</b><br><img src="docs/effects/fireworks.gif" width="400" alt="fireworks"><br><sub>Characters launch and explode like fireworks and fall into place</sub> |
| <b>highlight</b><br><img src="docs/effects/highlight.gif" width="400" alt="highlight"><br><sub>Run a specular highlight across the text</sub> | <b>laseretch</b><br><img src="docs/effects/laseretch.gif" width="400" alt="laseretch"><br><sub>A laser etches characters onto the terminal</sub> |
| <b>matrix</b><br><img src="docs/effects/matrix.gif" width="400" alt="matrix"><br><sub>Matrix digital rain effect</sub> | <b>middleout</b><br><img src="docs/effects/middleout.gif" width="400" alt="middleout"><br><sub>Text expands in a single row or column in the middle of the canvas then out</sub> |
| <b>orbittingvolley</b><br><img src="docs/effects/orbittingvolley.gif" width="400" alt="orbittingvolley"><br><sub>Four launchers orbit the canvas firing volleys of characters inward to build the input text from the center out</sub> | <b>overflow</b><br><img src="docs/effects/overflow.gif" width="400" alt="overflow"><br><sub>Input text overflows and scrolls the terminal in a random order until eventually appearing ordered</sub> |
| <b>pour</b><br><img src="docs/effects/pour.gif" width="400" alt="pour"><br><sub>Pours the characters into position from the given direction</sub> | <b>print</b><br><img src="docs/effects/print.gif" width="400" alt="print"><br><sub>Lines are printed one at a time following a print head. Print head performs line feed, carriage return</sub> |
| <b>rain</b><br><img src="docs/effects/rain.gif" width="400" alt="rain"><br><sub>Rain characters from the top of the canvas</sub> | <b>randomsequence</b><br><img src="docs/effects/randomsequence.gif" width="400" alt="randomsequence"><br><sub>Prints the input data in a random sequence</sub> |
| <b>rings</b><br><img src="docs/effects/rings.gif" width="400" alt="rings"><br><sub>Characters are dispersed and form into spinning rings</sub> | <b>scattered</b><br><img src="docs/effects/scattered.gif" width="400" alt="scattered"><br><sub>Text is scattered across the canvas and moves into position</sub> |
| <b>slice</b><br><img src="docs/effects/slice.gif" width="400" alt="slice"><br><sub>Slices the input in half and slides it into place from opposite directions</sub> | <b>slide</b><br><img src="docs/effects/slide.gif" width="400" alt="slide"><br><sub>Slide characters into view from outside the terminal</sub> |
| <b>smoke</b><br><img src="docs/effects/smoke.gif" width="400" alt="smoke"><br><sub>Smoke floods the canvas colorizing any characters it crosses</sub> | <b>spotlights</b><br><img src="docs/effects/spotlights.gif" width="400" alt="spotlights"><br><sub>Spotlights search the text area, illuminating characters, before converging in the center and expanding</sub> |
| <b>spray</b><br><img src="docs/effects/spray.gif" width="400" alt="spray"><br><sub>Draws the characters spawning at varying rates from a single point</sub> | <b>swarm</b><br><img src="docs/effects/swarm.gif" width="400" alt="swarm"><br><sub>Characters are grouped into swarms and move around the terminal before settling into position</sub> |
| <b>sweep</b><br><img src="docs/effects/sweep.gif" width="400" alt="sweep"><br><sub>Sweep across the canvas to reveal uncolored text, reverse sweep to color the text</sub> | <b>synthgrid</b><br><img src="docs/effects/synthgrid.gif" width="400" alt="synthgrid"><br><sub>Create a grid which fills with characters dissolving into the final text</sub> |
| <b>thunderstorm</b><br><img src="docs/effects/thunderstorm.gif" width="400" alt="thunderstorm"><br><sub>Create a thunderstorm in the terminal</sub> | <b>unstable</b><br><img src="docs/effects/unstable.gif" width="400" alt="unstable"><br><sub>Spawn characters jumbled, explode them to the edge of the canvas, then reassemble them in the correct layout</sub> |
| <b>vhstape</b><br><img src="docs/effects/vhstape.gif" width="400" alt="vhstape"><br><sub>Lines of characters glitch left and right and lose detail like an old VHS tape</sub> | <b>waves</b><br><img src="docs/effects/waves.gif" width="400" alt="waves"><br><sub>Waves travel across the terminal leaving behind the characters</sub> |
| <b>wipe</b><br><img src="docs/effects/wipe.gif" width="400" alt="wipe"><br><sub>Wipes the text across the terminal to reveal characters</sub> |  |

Every effect takes its own options — `ttfx <effect> --help`. A few of the GIFs above shorten a
timed phase so the loop stays watchable (`matrix --rain-time 3`, `thunderstorm --storm-time 3`,
`vhstape --total-glitch-time 250`, `spotlights --search-duration 80`, `errorcorrect
--error-pairs 0.5`); everything else is stock.

## Fidelity

This is a *parity port*, not a reimplementation-in-spirit. Given the same input, config, and
random draws, ttfx produces **byte-identical frames** to the Python original — verified
mechanically in CI against a pinned upstream checkout (v0.15.0), not by eyeballing.

| Suite | Checks | What it proves |
|---|---|---|
| `tools/parity/run_suite.sh` | 354 | every effect's frame stream, byte for byte, across configs and seeds |
| `tools/parity/tty_compare.sh` | 41 | the full terminal byte stream — canvas prep, cursor moves, teardown |
| `tools/tests/cli_corpus.sh` | 19 | exit codes and stdout/stderr routing |
| `tools/tests/*_behavior.py` | pty | what only a real terminal shows: resize restarts, signal teardown |
| `cargo test` | goldens + traces | easing/geometry/gradient values and engine state machines |

`./bin/test` runs the lot, which is all CI does.

Making that possible meant reproducing upstream's quirks deliberately, not "fixing" them:
Python's banker's rounding, gradients built from integer floor division rather than float
interpolation, a bezier arc-length approximation that drops its final segment, and looping
scenes that report themselves complete on every tick. They're catalogued in
[`plan.md`](plan.md); the places where Python's unordered iteration had to be pinned down are
in [`docs/ordering-inventory.md`](docs/ordering-inventory.md).

**Two deliberate differences.** Random number generation is not bit-compatible with CPython —
ttfx uses xoshiro256++, so `--seed` is reproducible within ttfx but won't match Python's
Mersenne Twister. (The parity harness swaps a shared PRNG into both sides, which is what makes
frame comparison possible at all.) And Python plugin effects aren't supported, since there's
no interpreter to load them.

## Usage

```
<producer> | ttfx [terminal options] <effect> [effect options]

ttfx --help                 # all 37 effects and the terminal options
ttfx <effect> --help        # options for one effect
ttfx --random-effect        # surprise me (--include-effects / --exclude-effects to filter)
ttfx --print-completion bash|zsh
```

Terminal options (canvas size and anchoring, color handling, frame rate, text wrapping) go
before the effect name; effect options after it. Option names and defaults match `tte`, so
existing invocations work with the binary name swapped.

## Building

```sh
cargo build --release
cargo build --release --target x86_64-unknown-linux-musl   # static, ~3.3 MB
```

`./bin/test` runs every suite. It needs python3, and the parity half needs a copy of
upstream, which it clones at the pinned commit on first run:

```sh
./tools/parity/fetch_reference.sh   # what bin/test calls; safe to run by hand
```

Upstream is not vendored here — the harness fetches it, because it's their code.

## Native Swift port

**Swift implements all 37 Rust effect counterparts (37/37 registry names match).** It remains WIP:
registered effects are not a claim of complete CLI or cross-platform parity. The measured Rust comparison
and its limits are below; the Rust/Python fidelity and benchmark sections above describe Rust, not Swift.

The native Swift work is intentionally a **port of a port**:

```text
TerminalTextEffects (Python, ChrisBuilds)
        ↓ parity port
Rust ttfx (this repository's production binary)
        ↓ native port in progress
Swift ttfx / TTFXSwiftUI / TTFXGalleryApp
```

The Swift code follows the Rust implementation rather than reimagining TTE directly. That keeps one
local oracle: Rust owns the production terminal behavior, while Swift proves itself against Rust-backed
parity tests and side-by-side visual comparison. It lives in the root Swift package and does **not**
replace the Rust `ttfx` product or change the Rust parity claims above. Status and architecture:
[`docs/swift-port/README.md`](docs/swift-port/README.md).

```sh
swift package resolve
swift build --product ttfx
printf 'Swift\nTTE' | swift run ttfx -- --canvas-width 12 --canvas-height 6 print
printf 'Swift\nTTE' | swift run ttfx -- --canvas-width 12 --canvas-height 6 print --print-speed 5
swift run ttfx -- print --help
swift run ttfx -- --print-completion bash
```

This toolchain’s `swift run` takes the executable name, not `--product`. Per-effect TTE flags
go after the effect name (`ttfx print --print-speed 5`, `ttfx rain --rain-symbols o .`).
Unknown effect flags are rejected. `ttfx <effect> --help` lists that effect’s flags.

### Native app examples

There are two native Swift app workflows in this repo:

| App | What it shows | How to run |
|---|---|---|
| `TTFXGalleryApp` | Live SwiftUI/Metal preview of one Swift effect at a time. You can change text, seed, canvas, effect, playback, and renderer. | `xcodegen generate && open TTFXGalleryApp.xcodeproj`, then run scheme **TTFXGalleryApp** on **My Mac** or an iOS Simulator. |
| `TTFX Video Comparison` | Four synchronized tracks: Rust terminal replay, Swift Metal, optional pure-Swift CLI, and optional SwiftUI. This is the visual parity review tool. | `./tools/video-comparison/capture.sh` once, then `./script/build_and_run.sh --compare`. |

Open the Xcode **app** project for the gallery, not the SwiftPM executable:

```sh
xcodegen generate
open TTFXGalleryApp.xcodeproj
```

Select scheme **TTFXGalleryApp** (product `TTFXGalleryApp.app`) and a destination
(**My Mac** or **iPhone Simulator**), then Run. The app bundle id is
`codes.suscodigos.ttfx.gallery`.

Do not Run the SwiftPM `TTFXGalleryApp` executable. That path is a bare binary with no
bundle id: on iPhone UIKit traps in `BKSHIDEvent`; on Mac you get `missing main bundle
identifier` and `linkd.autoShortcut` XPC errors.

The SwiftPM executable remains for `swift build --product TTFXGalleryApp` / tests. `TTFXGalleryApp`
lists `EffectRegistry.names` in registry order and lets you edit text, seed, canvas, effect, and
playback through the native SwiftUI snapshot path.

### TTFX Video Comparison

The comparison app uses real project outputs, but they are generated artifacts and are intentionally
ignored by Git. A local capture library looks like this:

```text
artifacts/video-comparison/
├── manifest.json
├── provenance.json
└── print/
    ├── rust.frames
    ├── rust.mp4
    ├── swift-cli.frames
    ├── swift-cli.mp4
    ├── swiftui.mp4
    └── metal.mp4
```

Generate it before opening the app:

```sh
./tools/video-comparison/capture.sh --effect print --max-frames 240
./script/build_and_run.sh --compare
```

That command creates real local videos you can inspect outside the app too:

```sh
open artifacts/video-comparison/print/rust.mp4
open artifacts/video-comparison/print/swift-cli.mp4
open artifacts/video-comparison/print/swiftui.mp4
open artifacts/video-comparison/print/metal.mp4
```

For a full visual sweep, omit `--effect print`; that produces four videos for each of all 37 effects
(148 videos). Capture integrity checks are not proof of effect equivalence. The app opens
`artifacts/video-comparison` automatically through `./script/build_and_run.sh --compare`.

Search and select an effect, press **Play** or Space, and scrub the shared timeline. Rust terminal and
Swift Metal always stay visible; the **Optional panes** buttons independently show/hide **Swift CLI**
(⌘1) and **SwiftUI** (⌘2). Older libraries remain loadable and show missing-recording notices for
absent optional tracks. **Speed** selects 0.5×–3× and applies to all four videos, including hidden panes,
and the shared timeline. Changing speed preserves position and pause state; timestamps remain media
seconds. Only the capture date is shown in the footer; source revision remains in the manifest.

If the app says `manifest.json` could not be opened, it means the selected/default library folder does
not contain a generated comparison library. Usually one of these happened:

- `./tools/video-comparison/capture.sh` has not been run yet on this checkout;
- the app was launched directly from Xcode or Finder without the `--library` argument, so its working
  directory was not the repository root;
- **Open Library…** was pointed at an effect folder like `artifacts/video-comparison/print` instead of
  the library root `artifacts/video-comparison`.

Fix it with:

```sh
./tools/video-comparison/capture.sh
./script/build_and_run.sh --compare
```

More detail: [`docs/swift-port/video-comparison.md`](docs/swift-port/video-comparison.md),
[`docs/swift-port/video-recording.md`](docs/swift-port/video-recording.md), and
[`docs/swift-port/video-comparison-schemas.md`](docs/swift-port/video-comparison-schemas.md).
Behavior changes require RED → GREEN → REFACTOR; see the observed toggle, selector, and playback-speed
[TDD evidence and remaining limits](docs/swift-port/video-comparison-tdd.md).

### Measured Swift parity against Rust

Verified on **2026-09-17, macOS 26.6.2 arm64, Swift 6.3.3**, at repository commit
`11e587ba781f14ea42ad929f0467ab3a6a732ea6`. Rust sources and Cargo files are unchanged from reference
`0f24d88408c8b815761c2c07da7dc9b411f63016`; the suite runs that local Rust checkout, not Python.

| Evidence | Observed result | Scope |
|---|---|---|
| `swift test --filter CompleteEffectParityTests` | **117/117 parameterized cases passed** (111 default runs + 6 timed runs; 2 test functions). | Every frame's ANSI bytes, frame count, and completion, with a 10,000-tick truncation guard. |
| Existing executable capture dumps | **37/37 Rust/Swift CLI pairs byte-identical**. | Recorded multiline sample, seed 42, 24×8 canvas, 25 FPS, virtual clock; not a full terminal session. |

The 111 runs use all 37 effects at defaults with three input/seed/canvas combinations: `TTFX\nRust + Swift\nVisual comparison` / 42 / 24×8; `Native Swift\n A B C\nParity!` / 7 / 16×6;
`Parity 2026\nSWIFT + RUST\n  Two spaces` / 123 / 18×7, all at 25 FPS. Six additional runs test
`matrix` and `thunderstorm` at 60, 17, and 0 FPS with seed 23, input `Clock test\nRust Swift`,
and a 16×6 canvas. Rust parity-dump mode and Swift effect ticks use deterministic frame-based time.
See [`CompleteEffectParityTests.swift`](tests/ttfx-effectsTests/CompleteEffectParityTests.swift).

This is **sampled default-effect parity**, not universal 37/37 parity. The full non-default configuration
corpus, Unicode/layout/ANSI preprocessing, random-selection continuation, and real terminal pacing,
resize, cancellation, and teardown still need comprehensive Rust-backed proof. The cross-platform CLI
specification's T01–T08 remain pending; macOS evidence does not certify Windows or Linux. See
[`cross-platform-cli-spec.md`](docs/swift-port/cross-platform-cli-spec.md) and
[`ODD task status`](odd/tasks/cross-platform-cli.md).

| Area | Current status |
|---|---|
| Core/effects | Native Swift core plus all 37 effect counterparts; measured full-run default cases are scoped above, not every configuration. |
| CLI | Native `ttfx` executable with Rust-style terminal options, TTE per-effect flags after the effect name, random-effect filtering, completions, and hidden parity-dump support. All 37 have parity-dump smoke coverage; the 37 existing CLI capture pairs match exactly for their recorded sample. Complete terminal/CLI parity remains pending. |
| SwiftUI/Metal | Optional `TTFXSwiftUI` library plus `TTFXGalleryApp.xcodeproj` for macOS and iOS Simulator. Headless CI proves command planning; visual Metal presentation still needs an interactive check. |
| Product scope | The Rust binary remains the production authority in this README. The Swift port is tracked in `docs/swift-port/` and `openspec/changes/native-swift-port/`. |

```sh
swift test --filter CompleteEffectParityTests
swift test --filter EffectFrameParityTests
swift test --filter CLIParityDumpTests
swift test --filter CLIParsingTests
swift test --filter TTFXSwiftUITests
swift test --filter galleryXcodeAppDeclaresBundleIdentifierAndIOSDestinations
swift test
```

## Rust production scope

Linux and macOS. Built for [Omarchy](https://omarchy.org) originally; nothing targets a
specific libc, and CI runs the tests and CLI corpus on both platforms. The byte-exact
parity suites stay pinned to Linux/glibc — Apple's libm rounds a few transcendentals a
last-ulp differently, which quantization hides in real frames but a bit-exact comparison
would surface.

## License

MIT — see [LICENSE](LICENSE), which carries both this project's copyright and the original
TerminalTextEffects copyright, and [NOTICE](NOTICE) for the attribution in full.
