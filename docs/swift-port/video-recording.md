# How TTFX video comparison recordings are made

This document describes the recording pipeline behind **TTFX Video Comparison**. It explains what is actually captured, which renderer produces each file, and why the generated videos are useful evidence without being a claim that every terminal or GPU will rasterize identically.

## Table of contents

- [Quick command](#quick-command)
- [Generated library layout](#generated-library-layout)
- [Recording pipeline](#recording-pipeline)
- [Rust terminal recording](#rust-terminal-recording)
- [Swift CLI recording](#swift-cli-recording)
- [SwiftUI recording](#swiftui-recording)
- [Swift Metal recording](#swift-metal-recording)
- [Timeline and completion rules](#timeline-and-completion-rules)
- [Regenerating old two-track libraries](#regenerating-old-two-track-libraries)
- [Related docs](#related-docs)

## Quick command

From the repository root:

```sh
./tools/video-comparison/capture.sh
./script/build_and_run.sh --compare
```

For a faster local smoke recording:

```sh
./tools/video-comparison/capture.sh --effect print --max-frames 240
./script/build_and_run.sh --compare
```

Prerequisites: macOS with Xcode/Swift, Cargo, working Metal support, and ffmpeg (default `/opt/homebrew/bin/ffmpeg`; override with `--ffmpeg`). No network installation is performed by this procedure.

The capture script builds the Rust binary, pure-Swift CLI, and Swift recorder, then runs `TTFXVideoCapture`.

## Generated library layout

The default library is generated under `artifacts/video-comparison/` and is intentionally ignored by Git.

```text
artifacts/video-comparison/
├── manifest.json
├── provenance.json
└── <effect>/
    ├── rust.frames
    ├── rust.mp4
    ├── swift-cli.frames
    ├── swift-cli.mp4
    ├── swiftui.mp4
    └── metal.mp4
```

`manifest.json` is what the app loads. For each effect it points to four synchronized panes:

| Pane | File | Producer |
|---|---|---|
| Rust terminal | `<effect>/rust.mp4` | Rust `ttfx --parity-dump` ANSI frames replayed through Swift/CoreText. |
| Swift CLI | `<effect>/swift-cli.mp4` | Actual pure-Swift `ttfx --parity-dump --virtual-clock` ANSI output replayed through CoreText. |
| Swift Metal | `<effect>/metal.mp4` | Native Swift effect frames rendered by `TTFXMetalRenderer`. |
| SwiftUI | `<effect>/swiftui.mp4` | Native Swift effect frames rendered by the SwiftUI fallback frame view. |

The app shows Rust terminal and Swift Metal plus optional Swift CLI and SwiftUI panes. **Show Swift CLI** and **Show SwiftUI** independently hide or show their panes.

## Recording pipeline

`tools/video-comparison/capture.sh` runs:

1. `cargo build --release`
2. `swift build --product ttfx`
3. `swift build --product TTFXVideoCapture`
4. `.build/.../TTFXVideoCapture` with any arguments passed through

`TTFXVideoCapture` then:

1. Resolves the repository root and default output directory.
2. Creates or refreshes `artifacts/video-comparison/`.
3. Records the source revision and dirty working-tree status in provenance.
4. Iterates over one effect (`--effect name`) or all `EffectRegistry.names`.
5. Writes one `manifest.json` entry per effect.

Default capture settings:

| Setting | Default |
|---|---:|
| Text | `TTFX\nRust + Swift\nVisual comparison` |
| Canvas | 24 columns × 8 rows |
| Pixel size | 16 × 24 per cell |
| Video size | 384 × 192 |
| FPS | 25 |
| Seed | 42 |
| Max frames | 3000 |

## Rust terminal recording

The Rust video uses the real Rust effect engine, but it is **not** a screen recording of Terminal.app or iTerm2.

For each effect, `TTFXVideoCapture` invokes the Rust binary with a fixed parity-dump command equivalent to:

```sh
target/release/ttfx \
  --parity-dump --virtual-clock \
  --seed 42 \
  --frame-rate 25 \
  --max-frames 3001 \
  --ignore-terminal-dimensions \
  --canvas-width 24 \
  --canvas-height 8 \
  --anchor-text sw \
  --anchor-canvas sw \
  <effect>
```

Rust emits length-prefixed ANSI frames. The recorder keeps those bytes in `<effect>/rust.frames`, then parses and rasterizes them with `ANSIRasterizer`:

- allocates a BGRA bitmap sized from the terminal grid;
- starts with a black canvas;
- interprets SGR color/style sequences;
- supports 16-color ANSI, xterm-256, truecolor foreground/background, bold, inverse, and resets;
- draws non-space Unicode scalars with CoreText/Menlo;
- pipes raw BGRA frames to ffmpeg as `rust.mp4`.

This is deterministic terminal-output replay. It is suitable for side-by-side review, but it does not claim to match every terminal emulator's font or rasterization choices.

## Swift CLI recording

The recorder launches the actual pure-Swift CLI executable next to `TTFXVideoCapture`, not an in-process effect or relabeled GUI recording. Both executable paths use identical arguments, UTF-8 stdin, seed, canvas, FPS, and a `maxFrames + 1` completion probe. The output is retained as `swift-cli.frames`, decoded with the same length-prefixed parser, and rasterized through the same `ANSIRasterizer` as Rust into `swift-cli.mp4`.

Select a different built executable and output folder explicitly:

```sh
./tools/video-comparison/capture.sh --swift-cli /absolute/path/to/ttfx \
  --effect print --max-frames 240 --output /tmp/ttfx-cli-comparison
```

`provenance.json` records `swiftCLIBinary` and `swiftCLICommand`. This track exercises ANSI serialization and the executable boundary; it does not certify effect parity or Windows/Linux support. Capture and replay remain macOS tooling.

## SwiftUI recording

The SwiftUI video uses the native Swift effect engine, not Rust.

For each tick:

1. Swift creates or advances the selected `EffectRegistry` effect.
2. The effect writes into a Swift `Frame`.
3. `TTFXFrameSnapshot` converts the frame into a stable snapshot.
4. `renderSwiftUIBGRA` draws the snapshot using the same production SwiftUI `TTFXFrameView` used by the gallery fallback. The renderer draws each snapshot cell with its foreground/background colors, including colored spaces, on a fixed 16 × 24 grid with Menlo 20. Glyph origins and baselines match the Rust replay; SwiftUI/CoreText antialiasing may differ. Uncolored foregrounds use terminal-default white; the native engine’s explicit-black sentinel is resolved as black foreground metadata, never as a visible background.
5. The BGRA frame is encoded to `<effect>/swiftui.mp4`.

The SwiftUI pane is useful because it separates effect behavior from the Metal renderer. If Rust and SwiftUI disagree, compare the underlying frame cells before deciding whether the cause is effect logic or rendering. If SwiftUI and Metal disagree with identical cells, inspect rendering. Existing recordings must be regenerated after renderer changes.

## Swift Metal recording

The Metal video also uses the native Swift effect engine. It renders the same `TTFXFrameSnapshot` as the SwiftUI path, but through the production Metal renderer:

1. `TTFXMetalRenderer` packs cells into a stable upload plan.
2. `MetalGlyphAtlas` rasterizes glyph coverage into an atlas.
3. `GlyphCell.metal` draws cell backgrounds and glyph coverage with per-cell colors.
4. The renderer exports a BGRA frame.
5. ffmpeg encodes it to `<effect>/metal.mp4`.

There is no software fallback in the Metal recording path. If Metal cannot encode GPU commands, capture fails instead of silently substituting a different renderer.

## Timeline and completion rules

The recorder writes one encoded video frame for each engine tick. It does not sample, interpolate, or stretch time.

The comparison app uses the maximum frame count among all present videos for the selected effect. If one visible video is shorter, it holds its final encoded frame while the others continue.

`completed` in the manifest means the effect finished before the safety limit. A recording that reaches `maxFrames` is labeled **Capture limit reached** and is not proof that the effect reached its final state.

Rust and Swift CLI ask for one extra frame (`maxFrames + 1`) so the recorder can distinguish a clean completion at the limit from truncation.

## Regenerating old two-track libraries

Older generated libraries may only contain:

```text
rust.mp4
metal.mp4
```

Those libraries still load, but the app shows a missing SwiftUI recording notice in the right pane. Regenerate the library to add `swiftui.mp4` and `swiftUI` manifest entries:

```sh
./tools/video-comparison/capture.sh
```

You can confirm the manifest contains SwiftUI entries with:

```sh
grep '"swiftUI"' artifacts/video-comparison/manifest.json | head
```

## Related docs

- [Video comparison guide](video-comparison.md) — how to open and inspect the generated videos.
- [Video comparison schemas](video-comparison-schemas.md) — exact `manifest.json` and `provenance.json` fields.
- [Metal toolchain](metal-toolchain.md) — installing and validating the Metal-backed Swift path.

## Verify a recording

```sh
swift test --filter TTFXComparisonTests
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames \
  artifacts/video-comparison/print/swift-cli.mp4
ffmpeg -v error -i artifacts/video-comparison/print/swift-cli.mp4 -f null -
```

Expect 384 × 192, configured FPS, and the `swiftCLI.frames` manifest count. Repeat decoding and metadata checks for every generated track. Inspect `swift-cli.frames` to separate executable output issues from replay issues. Libraries without `swiftCLI` still load and display a missing-recording notice; regenerate to add the track. Both optional panes have independent visibility toggles, but hiding a pane does not remove its player from the synchronized timeline.
