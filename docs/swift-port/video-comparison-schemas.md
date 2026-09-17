# Video comparison schemas

This document explains the data files produced by `TTFXVideoCapture` and consumed by **TTFX Video Comparison**.

The generated library lives under `artifacts/video-comparison/` by default:

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

Use this guide when you need to inspect, validate, regenerate, or hand-edit a comparison library. For the recording pipeline that creates these files, see [How TTFX video comparison recordings are made](video-recording.md).

## Quick use

Generate or refresh the default library:

```sh
./tools/video-comparison/capture.sh
```

Generate one effect into a separate folder:

```sh
./tools/video-comparison/capture.sh \
  --effect print \
  --max-frames 120 \
  --output /tmp/ttfx-print-comparison
```

Open a library in the app:

```sh
./script/build_and_run.sh --compare
# or choose the folder with Open Library… inside the app
```

## `manifest.json`

`manifest.json` is the app-facing index. It tells the comparison app which effects are present, where each video file is, how long each recording is, and which capture settings were used.

Swift type:

```swift
ComparisonManifest
```

Current version:

```json
"version": 1
```

### Shape

```json
{
  "version": 1,
  "generatedAt": "<ISO-8601 capture timestamp>",
  "revision": "<git revision or unknown>",
  "text": "TTFX\nRust + Swift\nVisual comparison",
  "seed": 42,
  "columns": 24,
  "rows": 8,
  "fps": 25,
  "maxFrames": 3000,
  "effects": [
    {
      "name": "print",
      "rust": { "path": "print/rust.mp4", "frames": 92, "completed": true, "provenance": "..." },
      "swiftUI": { "path": "print/swiftui.mp4", "frames": 92, "completed": true, "provenance": "..." },
      "metal": { "path": "print/metal.mp4", "frames": 92, "completed": true, "provenance": "..." }
    }
  ]
}
```

### Fields

| Field | Type | Meaning | How to use it |
|---|---:|---|---|
| `version` | integer | Manifest schema version. Currently must be `1`. | Reject or migrate if this changes. |
| `generatedAt` | string | ISO-8601 generation timestamp. | Display or compare library freshness. |
| `revision` | string | Git revision used for capture, with ` (working tree modified)` when dirty. If run outside Git, records `unknown (not a git repository)`. | Use for provenance, not for loading logic. |
| `text` | string | Input text passed to Rust and Swift. | Single-effect reruns must match the existing library. |
| `seed` | integer | Deterministic seed. | Single-effect reruns must match the existing library. |
| `columns` | integer | Terminal/grid columns. Must be positive. | Controls video aspect ratio and validation. |
| `rows` | integer | Terminal/grid rows. Must be positive. | Controls video aspect ratio and validation. |
| `fps` | integer | Frames per second. Must be positive. | Used for playback duration and timeline sync. |
| `maxFrames` | integer | Capture safety limit. | A recording can be marked incomplete when this limit is reached. |
| `effects` | array | Per-effect entries. Effect names must be unique. | The app list and players are built from this array. |

### Loader rules

`ComparisonManifest.load(from:)` enforces:

- `version == 1`;
- `fps > 0`;
- `columns > 0`;
- `rows > 0`;
- effect names are unique;
- each referenced video has `frames > 0`;
- each referenced video path exists;
- each video path is relative and stays inside the selected library folder.

If any rule fails, the app reports an invalid manifest or missing video.

## `ComparisonEffect`

An effect entry groups all render surfaces for one effect name.

Swift type:

```swift
ComparisonEffect
```

### Shape

```json
{
  "name": "beams",
  "rust": { "path": "beams/rust.mp4", "frames": 734, "completed": true, "provenance": "..." },
  "swiftUI": { "path": "beams/swiftui.mp4", "frames": 734, "completed": true, "provenance": "..." },
  "metal": { "path": "beams/metal.mp4", "frames": 734, "completed": true, "provenance": "..." }
}
```

### Fields

| Field | Type | Meaning | How to use it |
|---|---:|---|---|
| `name` | string | Effect name from `EffectRegistry.names`. | Used as the stable ID and folder name convention. |
| `rust` | `ComparisonVideo` | Rust terminal ANSI replay video. | Always required. |
| `swiftCLI` | `ComparisonVideo?` | Pure-Swift executable ANSI replay video. | Optional for legacy two/three-track libraries. |
| `swiftUI` | `ComparisonVideo?` | SwiftUI fallback video. | Optional for backward compatibility with old two-track libraries. |
| `metal` | `ComparisonVideo` | Swift Metal renderer video. | Always required. |

### Compatibility rule

`swiftUI` is optional. Older libraries generated before the SwiftUI track contain only:

```json
"rust": { ... },
"metal": { ... }
```

Those libraries still load. The app shows a right-side missing-recording notice when **Show SwiftUI** is enabled but `swiftUI` is absent for the selected effect. Regenerate with `./tools/video-comparison/capture.sh` to add `swiftui.mp4` and `swiftUI` manifest entries.

### Timeline rule

The comparison app computes each effect's duration from the maximum frame count across its present videos. Shorter videos hold their final encoded frame; the app does not stretch duration.

## `ComparisonVideo`

A video entry describes one rendered surface.

Swift type:

```swift
ComparisonVideo
```

### Shape

```json
{
  "path": "print/metal.mp4",
  "frames": 92,
  "completed": true,
  "provenance": "Swift effect engine rendered by the gallery’s production Metal atlas and shaders to GPU textures."
}
```

### Fields

| Field | Type | Meaning | How to use it |
|---|---:|---|---|
| `path` | string | Relative path from the library root to the `.mp4`. | Must not be absolute or escape the library root. |
| `frames` | integer | Number of encoded engine frames. | Used for duration: `frames / fps`. Must be positive. |
| `completed` | boolean | Whether the effect completed before `maxFrames`. | Displayed as `Complete` or `Capture limit reached`. |
| `provenance` | string | Human-readable rendering source. | Shown in the app under the pane. |

### Known surfaces

| Surface | File | Meaning |
|---|---|---|
| Rust terminal | `<effect>/rust.mp4` | Rust `--parity-dump` ANSI frames replayed through CoreText/Menlo. |
| Swift CLI | `<effect>/swift-cli.mp4` | Actual pure-Swift CLI ANSI frames replayed through CoreText/Menlo. |
| SwiftUI | `<effect>/swiftui.mp4` | Swift effect frames drawn by the SwiftUI fallback frame view. |
| Swift Metal | `<effect>/metal.mp4` | Swift effect frames drawn by the Metal glyph atlas/shader renderer. |

## `provenance.json`

`provenance.json` records capture-level metadata that is useful for audits and debugging. It is not required by `ComparisonManifest.load(from:)`, but generated libraries should include it.

Swift shape:

```swift
[String: String]
```

### Shape

```json
{
  "rustBinary": "/Users/julian/miscodigos/ttfx/target/release/ttfx",
  "ffmpegBinary": "/opt/homebrew/bin/ffmpeg",
  "rustCommand": "--parity-dump --seed 42 --frame-rate 25 --max-frames 3001 --ignore-terminal-dimensions --canvas-width 24 --canvas-height 8 --anchor-text sw --anchor-canvas sw EFFECT",
  "workingTreeStatus": " M README.md\n",
  "captureMethod": "Rust ANSI replay through CoreText; Swift native effect frames through production Metal shaders; one encoded frame per engine tick. No frame sampling or duration normalization."
}
```

### Fields

| Field | Meaning | How to use it |
|---|---|---|
| `rustBinary` | Absolute path used for the Rust oracle binary. | Check when capture fails with missing `ttfx`. Override with `--rust`. |
| `swiftCLIBinary` | Actual pure-Swift CLI executable path. | Override with `--swift-cli`. |
| `swiftCLICommand` | Same arguments as Rust, including `--virtual-clock`. | Reproduce the executable dump. |
| `ffmpegBinary` | Path used for video encoding. | Override with `--ffmpeg` when Homebrew is not under `/opt/homebrew`. |
| `rustCommand` | Template command used for Rust frame dumps. `EFFECT` is replaced per effect. | Reproduce or debug Rust capture. |
| `workingTreeStatus` | `git status --porcelain` output, or `unavailable: not a git repository`. | Audit whether videos came from dirty sources. |
| `captureMethod` | Human-readable summary of renderer paths. | Include in reports to avoid confusing video capture with screen recording. |

## `<effect>/rust.frames`

`rust.frames` is not JSON. It is the preserved Rust parity-dump stream.

Producer:

```sh
target/release/ttfx --parity-dump ... <effect>
```

Format:

```text
<byte-count>\n
<exact ANSI frame bytes>\n
<byte-count>\n
<exact ANSI frame bytes>\n
...
```

Rules enforced by `TTFXVideoCapture.parseFrames`:

- the length line must parse as a non-negative integer;
- the next `length` bytes must decode as UTF-8;
- the frame must be followed by a newline byte;
- truncated or malformed data fails capture.

Use `rust.frames` when you need to distinguish a Rust engine/output issue from a rasterization/video issue. The `rust.mp4` pixels are derived from this file, but this file is the exact Rust ANSI evidence.

## Per-effect files

Each effect directory is self-contained:

```text
<effect>/rust.frames
<effect>/rust.mp4
<effect>/swiftui.mp4
<effect>/metal.mp4
```

Do not edit the `.mp4` files without updating `manifest.json`; frame counts and completion status will become misleading.

## Safe manual edits

Safe:

- changing `provenance` text for a video;
- removing an entire effect entry and its directory;
- loading an older manifest with no `swiftUI` field;
- changing `generatedAt` for annotation purposes.

Risky:

- changing `frames` without re-encoding the video;
- changing `fps`, `columns`, or `rows` in an existing library;
- pointing `path` outside the library root — the loader rejects this;
- mixing effects captured with different `text`, `seed`, `fps`, `columns`, or `rows`.

Unsupported:

- `version` values other than `1`;
- absolute video paths;
- path traversal such as `../outside.mp4`;
- zero-frame videos.

## Regeneration workflows

### Full library

```sh
./tools/video-comparison/capture.sh
```

### One effect, preserving compatible existing entries

```sh
./tools/video-comparison/capture.sh --effect rings --max-frames 10000
```

Single-effect reruns preserve other manifest entries only when these match the existing library:

- `text`
- `seed`
- `fps`
- `columns`
- `rows`

If they differ, use a new `--output` folder.

### Running from Xcode or outside the repo

`TTFXVideoCapture` resolves the project root in this order:

1. `TTFX_REPOSITORY_ROOT` environment variable;
2. ancestors of the current working directory containing both `Cargo.toml` and `Package.swift`;
3. ancestors of the compiled Swift source path;
4. the current working directory as a fallback.

If the Rust binary is not at `<project-root>/target/release/ttfx`, pass it explicitly:

```sh
TTFX_REPOSITORY_ROOT=/Users/julian/miscodigos/ttfx \
  .build/debug/TTFXVideoCapture \
  --rust /Users/julian/miscodigos/ttfx/target/release/ttfx \
  --output /tmp/ttfx-video-comparison
```

## Validation checklist

After generating or editing a library:

1. Open it with **TTFX Video Comparison**.
2. Confirm the effect count in the sidebar footer.
3. Select an effect and check Rust, SwiftUI, and Metal panes.
4. Toggle **Show SwiftUI** off and on.
5. Scrub the timeline to the end; shorter videos should hold their final frame.
6. If debugging Rust, inspect `<effect>/rust.frames` before inspecting `rust.mp4`.

## Optional Swift CLI track

Version 1 additionally permits `swiftCLI` with the same validation as every `ComparisonVideo`. Missing, escaping, or zero-frame declared tracks are rejected; absent tracks remain backward compatible. `swift-cli.frames` uses the exact length-prefixed UTF-8 format described for `rust.frames`. The pane reports missing recording for old libraries.
