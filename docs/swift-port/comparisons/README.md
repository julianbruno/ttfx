# Rust versus Swift Metal video comparisons

These 37 full-length videos place **Rust on the left** and **Swift Metal on the right**.
The root README displays all 37 labeled GIF previews inline. Each is the first at most six seconds at the original 25 fps, scaled to 576 × 174. Shorter effects appear in full; the MP4 files retain each complete animation.

## What was recorded

- Source: `artifacts/video-comparison/manifest.json`, generated September 17, 2026 at 20:39:38 UTC.
- Capture revision: `789a0463cb9a553ef4444fe876780f231194da65`, with working-tree modifications recorded by the original capture tooling.
- Input: `TTFX\nRust + Swift\nVisual comparison`; seed 42; 24 × 8 cells; 25 frames per second.
- Rust: actual terminal ANSI output replayed with CoreText/Menlo, not a terminal screen recording.
- Metal: Swift effect-engine frames rendered with the gallery's production Metal atlas/shaders to GPU textures.
- Source panels remain 384 × 192 pixels. `labels.png` adds a permanent 40-pixel header; output is 768 × 232.
- Every pair has matching source frame counts and durations. Full videos retain all frames at their original cadence: no speed changes, interpolation, or duration normalization.

These are visual samples, **not proof of universal parity**. Rust terminal glyph rendering and Metal rasterization differ, and H.264/GIF encoding is lossy. Consult the root README for separately measured ANSI parity and its limitations.

## Reproduce locally

First generate the original captures using [the capture guide](../video-recording.md).
Then run from the repository root with FFmpeg/libx264 installed:

```sh
mkdir -p docs/swift-port/comparisons
for dir in artifacts/video-comparison/*/; do
  effect=$(basename "$dir")
  ffmpeg -v error -y -i "$dir/rust.mp4" -i "$dir/metal.mp4" \
    -loop 1 -framerate 25 -i docs/swift-port/comparisons/labels.png \
    -filter_complex '[0:v][1:v]hstack=inputs=2:shortest=1[panels];[2:v][panels]vstack=inputs=2:shortest=1[v]' \
    -map '[v]' -an -c:v libx264 -preset medium -crf 23 \
    -pix_fmt yuv420p -movflags +faststart \
    "docs/swift-port/comparisons/$effect.mp4"
done
for video in docs/swift-port/comparisons/*.mp4; do
  ffmpeg -v error -y -i "$video" -t 6 \
    -filter_complex '[0:v]scale=576:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse' \
    -loop 0 "${video%.mp4}-preview.gif"
done
```

Before stacking, verify source pairs have identical fps, frame counts and duration; `shortest=1` is safe for this captured set only. For a future mismatched set, resolve the mismatch rather than silently truncating either track. Reuse the tracked label strip (Arial 18, white text, dark background); no `drawtext` support is required.

## Validation and playback

`provenance.json` records capture settings, FFmpeg version, each input MP4's SHA-256, output frame counts/durations, and verification results. All 74 source streams and 37 output streams were probed; each output passed a complete error-fatal decode:

```sh
ffprobe -v error -count_frames -show_streams -of json docs/swift-port/comparisons/decrypt.mp4
ffmpeg -v error -xerror -i docs/swift-port/comparisons/decrypt.mp4 -f null -
```

Relative MP4 links allow opening/downloading the full comparison. GitHub README inline MP4 playback is not assumed or verified; the 37 animated GIFs provide inline previews. GIF timing uses 40 ms per frame, representing 25 fps exactly; preview looping does not imply the source effect loops. The preview catalog adds a download cost; `provenance.json` records actual per-file and total sizes. Original capture artifacts remain ignored and are not duplicated in this folder.

All 37 GIF previews passed dimensions, expected frame count (`min(source frames, 150)`), duration (`frames / 25`) and complete error-fatal decoding. No source frames were interpolated or sped up. GIF scaling/palette encoding remains lossy. GitHub-hosted rendering is not independently verified.
