# TTFX Video Comparison

Generate local Rust, Swift Metal, and SwiftUI videos for each effect, then inspect them together in the native **TTFX Video Comparison** app.

## Table of contents

- [Quick path](#quick-path)
- [What the app shows](#what-the-app-shows)
- [What gets generated](#what-gets-generated)
- [How recording works](#how-recording-works)
- [Long effects and reruns](#long-effects-and-reruns)
- [Troubleshooting](#troubleshooting)
- [Current local capture](#current-local-capture)
- [Related docs](#related-docs)

## Quick path

From the repository root:

```sh
./tools/video-comparison/capture.sh
./script/build_and_run.sh --compare
```

For a faster smoke run that refreshes only one effect:

```sh
./tools/video-comparison/capture.sh --effect print --max-frames 240
./script/build_and_run.sh --compare
```

The recordings and their manifest live in `artifacts/video-comparison/`. That directory is generated and ignored by Git.

## What the app shows

The comparison app opens `artifacts/video-comparison/` automatically when launched through `./script/build_and_run.sh --compare`. **Open Library…** can load another generated folder.

For each selected effect, the app shows three synchronized panes:

| Position | Pane | Source |
|---|---|---|
| Left | Rust terminal | Rust `ttfx --parity-dump` ANSI output replayed by Swift/CoreText. |
| Middle | Swift Metal | Native Swift effect frames rendered by the production Metal renderer. |
| Right | SwiftUI | Native Swift effect frames rendered by the SwiftUI fallback view. |

Use **Play** or Space to play/pause, and scrub the shared timeline. All visible videos use the same host clock. If one visible video ends earlier, it holds its final frame while the others continue.

The right SwiftUI pane is optional: **Show SwiftUI** hides or shows it. If an old two-track library has no `swiftui.mp4` or `swiftUI` manifest entries, the app keeps the right pane as a missing-recording notice until the library is regenerated.

## What gets generated

The default generated layout is:

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

Each file has a different role:

| File | Meaning |
|---|---|
| `manifest.json` | App-facing index: effect names, video paths, frame counts, completion flags, capture settings. |
| `provenance.json` | Capture-level audit metadata: Rust binary path, ffmpeg path, Rust command template, working-tree status. |
| `<effect>/rust.frames` | Original length-prefixed ANSI frames emitted by Rust. |
| `<effect>/rust.mp4` | Rust terminal replay video. |
| `<effect>/metal.mp4` | Swift Metal video. |
| `<effect>/swiftui.mp4` | SwiftUI fallback video. |

The default sample uses the same text, seed, canvas, and frame rate for all panes:

```text
TTFX
Rust + Swift
Visual comparison
```

| Setting | Default |
|---|---:|
| Canvas | 24 × 8 terminal cells |
| Cell size | 16 × 24 pixels |
| Video size | 384 × 192 pixels |
| FPS | 25 |
| Seed | 42 |
| Safety limit | 3000 frames |

## How recording works

The short version:

1. `tools/video-comparison/capture.sh` builds the Rust binary with `cargo build --release`.
2. It builds the Swift recorder with `swift build --product TTFXVideoCapture`.
3. `TTFXVideoCapture` runs Rust once per effect with `--parity-dump` and records `rust.frames`.
4. Swift replays the Rust ANSI frames through CoreText/Menlo into `rust.mp4`.
5. Swift runs the native effect engine and records the same ticks twice: once through SwiftUI into `swiftui.mp4`, once through Metal into `metal.mp4`.
6. The recorder writes or updates `manifest.json` after each effect.

For the full pipeline, renderer boundaries, and exact assumptions, see [How TTFX video comparison recordings are made](video-recording.md).

## Long effects and reruns

The default safety limit is 3,000 frames (120 seconds at 25 fps). The app labels recordings that reach this limit as **Capture limit reached**. A limit does not establish visual parity or effect completion.

Regenerate a specific effect with a larger budget:

```sh
./tools/video-comparison/capture.sh --effect rings --max-frames 10000
```

A single-effect rerun preserves other entries in a compatible library. Use `--output /absolute/folder` for another library, or `--fps`, `--seed`, `--rust`, and `--ffmpeg` to override capture inputs.

For manual review, inspect:

- initial state;
- motion and ordering;
- foreground/background colors;
- particle behavior;
- final text;
- mismatched durations or completion flags.

Matching videos are visual evidence for the chosen sample and seed only. They do not prove global effect equivalence.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `manifest.json` could not be opened | The selected/default folder is not a generated comparison library. | Run `./tools/video-comparison/capture.sh`, then `./script/build_and_run.sh --compare`. |
| Right pane says no SwiftUI recording | The library was generated before the SwiftUI track existed. | Regenerate with `./tools/video-comparison/capture.sh`. |
| App opens but shows old data | UserDefaults may remember a previous library path. | Use **Open Library…** and choose `artifacts/video-comparison`, or pass `--library` through the launch script. |
| A recording says capture limit reached | The effect hit `--max-frames`. | Rerun that effect with a higher limit, e.g. `--effect rings --max-frames 10000`. |
| Metal capture fails | No usable Metal device/command encoding path. | Run on a macOS machine with Metal support; the recorder does not silently substitute SwiftUI. |

Quick manifest check:

```sh
grep '"swiftUI"' artifacts/video-comparison/manifest.json | head
```

## Current local capture

The current local library was regenerated at **2026-09-17T17:01:22Z**.

| Metric | Value |
|---|---:|
| Effects | 37 |
| Videos | 111 |
| Effects with SwiftUI track | 37 |
| Incomplete recordings | 0 |
| Total encoded frames | 37,848 |

`rings` currently has 1,398 frames in all three panes: Rust terminal, Swift Metal, and SwiftUI.

`artifacts/video-comparison/validation.json` may be stale after regeneration unless you rerun the validation helper that produced it. Treat `manifest.json` as the app's source of truth for the loaded library.

## Related docs

- [How TTFX video comparison recordings are made](video-recording.md)
- [Video comparison schemas](video-comparison-schemas.md)
- [Metal toolchain for the Swift port](metal-toolchain.md)
