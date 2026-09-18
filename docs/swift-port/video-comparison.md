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

Use **Search effects** to find an effect by name (case-insensitive; surrounding spaces are ignored). The native sidebar keeps registry order and shows recording status: **Not recorded**, **Recorded** with its track count, or **Capture limited** when any present track is incomplete. The footer counts matching effects and how many have recordings. No results? Use **Clear search**. Searching does not change the current effect or reset playback, even when its row disappears. Missing effects remain selectable; the detail provides an exact single-effect capture command, followed by **Reload**. Row selection supports native keyboard navigation.

For each selected effect, the app shows four synchronized panes:

| Position | Pane | Source |
|---|---|---|
| Left | Rust terminal | Rust `ttfx --parity-dump` ANSI output replayed by Swift/CoreText. |
| Middle | Swift Metal | Native Swift effect frames rendered by the production Metal renderer. |
| Optional | Swift CLI | Actual pure-Swift `ttfx --parity-dump --virtual-clock` ANSI output replayed by CoreText. |
| Optional | SwiftUI | Native Swift effect frames rendered by the SwiftUI fallback view. |

Use **Play** or Space to play/pause, and scrub the shared timeline. Choose **Speed** beside Play: 0.5×, 0.75×, 1× (default), 1.25×, 1.5×, 2×, 2.5×, or 3×. All present videos, including hidden panes, use the selected speed and the same host clock. Changing speed during playback preserves the current media position; changing it while paused keeps playback paused. Timeline and duration labels remain source-media seconds, not adjusted wall-clock duration. The speed stays selected when switching effects in the current window and resets to 1× in a new window. If one video ends earlier, it holds its final frame while the others continue.

The **Optional panes** group contains independent **Swift CLI** and **SwiftUI** toggle buttons. Each shows **Visible** with a checkmark or **Hidden** with an empty circle, so state does not rely on color. Use ⌘1 for Swift CLI and ⌘2 for SwiftUI, or focus either control and activate it with the keyboard. Hover for renderer details; VoiceOver announces the pane name and visibility. The group wraps when space is limited. Visibility belongs to the window and is restored with its scene, not saved as a global preference. Rust terminal and Swift Metal always remain visible. Older libraries missing `swiftCLI` show a CLI missing-recording notice. If an old two-track library has no `swiftui.mp4` or `swiftUI` manifest entries, the app keeps the right pane as a missing-recording notice until the library is regenerated.

## What gets generated

The default generated layout is:

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

The current local library was regenerated at **2026-09-17T20:39:38Z**.

| Metric | Value |
|---|---:|
| Effects | 37 |
| Videos | 148 |
| Effects with SwiftUI track | 37 |
| Effects with Swift CLI track | 37 |
| Incomplete recordings | 0 |
| Total encoded frames | 50,464 |

`rings` currently has 1,398 frames in all four panes: Rust terminal, Swift CLI, Swift Metal, and SwiftUI.

All 148 videos passed ffprobe frame-count, dimensions, and FPS checks plus full ffmpeg decode. All 74 executable dump streams passed UTF-8 framing and completion/cap checks. `artifacts/video-comparison/validation.json` stores the local results and Swift CLI binary SHA-256; it becomes stale on the next regeneration. Treat `manifest.json` as the app's source of truth. These checks validate recordings, not effect parity.

## Related docs

- [How TTFX video comparison recordings are made](video-recording.md)
- [Video comparison schemas](video-comparison-schemas.md)
- [Metal toolchain for the Swift port](metal-toolchain.md)

## Swift CLI track

Capture builds and executes the pure-Swift `ttfx` binary with the same deterministic arguments and UTF-8 input as Rust. Override it with `--swift-cli /absolute/path/to/ttfx`. Its length-prefixed ANSI dump is saved as `swift-cli.frames` and replayed through CoreText into `swift-cli.mp4`; this is not a SwiftUI or Metal recording. Legacy libraries may omit the optional `swiftCLI` track. A max-frames-plus-one probe marks capped recordings without stretching their duration. This macOS capture tooling does not certify CLI portability or effect parity.
