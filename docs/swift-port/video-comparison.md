# Compare Rust and Swift Metal effects on macOS

Generate videos from each renderer for all 37 effects, then inspect them together in the native **TTFX Video Comparison** app.

```sh
./tools/video-comparison/capture.sh
./script/build_and_run.sh --compare
```

The recordings and their manifest live in `artifacts/video-comparison/`. The app opens that folder automatically; **Open Library…** also loads another generated folder. Select an effect, press **Play** (Space), or scrub the shared timeline. All visible videos start against the same host clock. A shorter video holds its final frame while the others continue. Use **Show SwiftUI** to hide the SwiftUI pane when you want a Rust-vs-Metal-only review.

## What the videos represent

| Video | Pixel source |
|---|---|
| Rust terminal | Actual Rust `--parity-dump` ANSI frames replayed by CoreText with Menlo. This is a deterministic terminal-output export, not a screen recording of a terminal application. |
| SwiftUI | Native Swift effect ticks drawn by the app's SwiftUI fallback frame view. |
| Swift Metal | Native Swift effect ticks drawn using the gallery's production Metal glyph atlas and shaders into GPU textures. There is no software fallback. |

Both use the same three-line text, 24×8 canvas anchored southwest, seed 42, and 25 frames per second. Every engine frame is encoded once, without sampling or stretching time. The capture path bypasses the gallery's wall-clock scheduler, so it assesses visual effect behavior and the Metal renderer rather than display scheduling. Font rasterization can differ between CoreText and the Metal atlas.

```text
TTFX
Rust + Swift
Visual comparison
```

Each effect folder contains `rust.mp4`, `swiftui.mp4`, `metal.mp4`, and the original length-prefixed `rust.frames` evidence. `manifest.json` records frame counts, completion state, capture settings and source revision. Older two-track libraries without `swiftui.mp4` still load; the app only shows the SwiftUI toggle when that track is present. `provenance.json` records commands and whether the working tree was modified. These are local generated artifacts, ignored by Git.

## Long effects and reruns

The default safety limit is 3,000 frames (120 seconds at 25 fps). The app labels recordings that reach this limit. Rust requests one extra frame to distinguish completion at the limit from truncation; Swift reports its actual completion status. A limit does not establish visual parity or effect completion.

Regenerate a specific effect with a larger budget:

```sh
./tools/video-comparison/capture.sh --effect rings --max-frames 10000
```

A single-effect rerun preserves other entries in a compatible library. Use `--output /absolute/folder` for another library, or `--fps`, `--seed`, `--rust`, and `--ffmpeg` to override capture inputs. Effect-specific option defaults remain each implementation's own defaults so discrepancies stay visible.

For manual comparison, inspect the initial state, motion/order, colors, particle behavior, and the final text. Pause and scrub near divergences. Matching videos are visual evidence for this sample and seed only; creating the recordings does not mark effects as equivalent.

## Verified capture — September 17, 2026

The current library was regenerated after the native Swift effect corrections and output-frame clearing fix at **2026-09-17 15:00:13 UTC**. All 37 pairs now have matching frame counts: **74 complete videos, no truncations**, totaling 11,546,993 bytes. `ffprobe` verified frame counts against the manifest, 384×192 dimensions and 25 fps; all 74 videos passed a full decode. See `artifacts/video-comparison/validation.json`.

For example, `rings` now has 1,398 frames (55.92 seconds) in both implementations. The earlier library, where 19 effects had different durations, is preserved locally in `artifacts/video-comparison-before-parity/`.

Native behavior is also checked independently of the video renderer: all 37 effects match Rust's complete ANSI glyph, position and RGB sequences and completion counts for three multiline inputs, seeds 42/7/123 and canvases 24×8, 16×6 and 18×7. Six additional Matrix/Thunderstorm cases verify requested rates of 60, 17 and 0 fps. This proves parity for those 117 cases; font rasterization and video compression can still differ.

The final Swift suite ran 188 tests, including the parameterized parity cases, historical configured-effect regressions, gallery, renderer and comparison playback tests. 187 passed in the combined run; one historical Rust subprocess reached its 30-second timeout and passed unchanged in isolation in 0.555 seconds. A separate public Swift CLI check matched all 37 held-out seed-123 sequences and the six clock sequences byte for byte.

```sh
swift test --disable-sandbox
```

The gallery, CLI, reusable effect engine and video exporter clear their output frame before each tick, so moving glyphs do not leave stale cells behind.

The rebuilt native comparison app loaded the refreshed library and was checked with `rings` playback, showing matching 55.92-second timelines. To reopen it, run `./script/build_and_run.sh --compare`. The script builds and launches `.build/apps/TTFXComparisonApp.app` with the generated library's absolute path.
