# How TTFX video comparison recordings are made

This document describes the recording pipeline behind **TTFX Video Comparison**. It explains what is actually captured, which renderer produces each file, and why the generated videos are useful evidence without being a claim that every terminal or GPU will rasterize identically.

## Table of contents

- [Quick command](#quick-command)
- [Generated library layout](#generated-library-layout)
- [Recording pipeline](#recording-pipeline)
- [Rust terminal recording](#rust-terminal-recording)
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

The capture script builds the Rust binary and the Swift recorder, then runs `TTFXVideoCapture`.

## Generated library layout

The default library is generated under `artifacts/video-comparison/` and is intentionally ignored by Git.

```text
artifacts/video-comparison/
├── manifest.json
├── provenance.json
└── <effect>/
    ├── rust.frames
    ├── rust.mp4
    ├── swiftui.mp4
    └── metal.mp4
```

`manifest.json` is what the app loads. For each effect it points to three synchronized panes:

| Pane | File | Producer |
|---|---|---|
| Rust terminal | `<effect>/rust.mp4` | Rust `ttfx --parity-dump` ANSI frames replayed through Swift/CoreText. |
| Swift Metal | `<effect>/metal.mp4` | Native Swift effect frames rendered by `TTFXMetalRenderer`. |
| SwiftUI | `<effect>/swiftui.mp4` | Native Swift effect frames rendered by the SwiftUI fallback frame view. |

The app layout is Rust terminal on the left, Swift Metal in the middle, and optional SwiftUI on the right. The **Show SwiftUI** toggle hides or shows the right pane.

## Recording pipeline

`tools/video-comparison/capture.sh` runs:

1. `cargo build --release`
2. `swift build --product TTFXVideoCapture`
3. `.build/.../TTFXVideoCapture` with any arguments passed through

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
  --parity-dump \
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

## SwiftUI recording

The SwiftUI video uses the native Swift effect engine, not Rust.

For each tick:

1. Swift creates or advances the selected `EffectRegistry` effect.
2. The effect writes into a Swift `Frame`.
3. `TTFXFrameSnapshot` converts the frame into a stable snapshot.
4. `renderSwiftUIBGRA` draws the snapshot using the same production SwiftUI `TTFXFrameView` used by the gallery fallback. The renderer draws each snapshot cell with its foreground/background colors, including colored spaces, on a fixed 16 × 24 grid with Menlo 20. Glyph origins and baselines match the Rust replay; SwiftUI/CoreText antialiasing may differ.
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

The comparison app uses the maximum frame count among the visible videos for the selected effect. If one visible video is shorter, it holds its final encoded frame while the others continue.

`completed` in the manifest means the effect finished before the safety limit. A recording that reaches `maxFrames` is labeled **Capture limit reached** and is not proof that the effect reached its final state.

Rust asks for one extra frame (`maxFrames + 1`) so the recorder can distinguish a clean completion at the limit from truncation.

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
