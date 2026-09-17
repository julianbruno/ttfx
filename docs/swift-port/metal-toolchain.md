# Metal toolchain for the Swift port

This project uses Metal only for the native Swift preview/export path. The Rust CLI remains the production terminal binary, and the Swift core/effects still own the animation behavior. Metal is the rendering backend that turns Swift effect frames into native macOS/iOS pixels.

## Why Metal is used here

| Need | Why Metal fits |
|---|---|
| Native app preview | `TTFXGalleryApp` needs a real drawable-backed preview, not only text snapshots. `MTKView` gives the SwiftUI app a native GPU surface. |
| Per-cell rendering | Effects are already represented as terminal cells: glyph, foreground color, background color, and grid position. Metal can draw those cells as quads efficiently. |
| SwiftUI fallback comparison | The app can switch between SwiftUI and Metal so rendering differences are visible without changing effect state. |
| Video comparison | `TTFXVideoCapture` can export the Swift Metal renderer to `metal.mp4` and compare it beside Rust terminal replay and SwiftUI fallback videos. |
| Headless test seams | The code separates upload/command planning from presentation, so CI can test buffer packing and command decisions even when no drawable is available. |

Metal is not used to define effect behavior. The effect engine produces `Frame` values first; Metal only presents those frames.

## What the Metal path contains

| File | Role |
|---|---|
| `Sources/ttfx-swift/SwiftUI/Renderer.swift` | Packs `TTFXFrameSnapshot` cells, owns `TTFXMetalRenderer`, builds command plans, draws/presents frames, and exports BGRA pixels for video capture. |
| `Sources/ttfx-swift/SwiftUI/MetalGlyphAtlas.swift` | Rasterizes glyph coverage into a texture atlas using CoreText, then lets Metal color the glyphs per cell. |
| `Sources/ttfx-swift/SwiftUI/Shaders/GlyphCell.metal` | Vertex/fragment shader for cell backgrounds and glyph coverage. |
| `Sources/ttfx-swift/SwiftUI/Views.swift` | `TTFXMetalFrameView`, the `MTKView` bridge used by SwiftUI. |
| `Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/*` | Gallery controls, renderer selection, and the **Use Metal** switch/fallback behavior. |
| `Sources/TTFXVideoCapture/TTFXVideoCapture.swift` | Uses the same Metal renderer to export `metal.mp4` for visual comparison. |

`Package.swift` copies the shader directory as a SwiftPM resource:

```swift
resources: [.copy("Shaders")]
```

That keeps the shader available when building through SwiftPM and when the Xcode app consumes the local package.

## How to get the Metal toolchain

You do not download Metal as a separate package. Metal ships with Apple’s developer tools and Apple platforms.

### Required on macOS

1. Install Xcode from the Mac App Store or Apple Developer downloads.
2. Select the active Xcode toolchain:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

3. Accept the license if needed:

```sh
sudo xcodebuild -license accept
```

4. Verify that SwiftPM can build the Metal-backed targets:

```sh
swift build --product TTFXGalleryApp
swift build --product TTFXVideoCapture
```

### Optional: Command Line Tools only

For package builds, Apple Command Line Tools may be enough on some machines:

```sh
xcode-select --install
```

But the app workflow in this repository expects full Xcode because `TTFXGalleryApp.xcodeproj`, iOS Simulator destinations, app bundles, and interactive GPU validation are Xcode-centered.

### Optional: XcodeGen

The checked-in project can be opened directly, but if you need to regenerate it from `project.yml`, install XcodeGen:

```sh
brew install xcodegen
xcodegen generate
```

Then open:

```sh
open TTFXGalleryApp.xcodeproj
```

Select the **TTFXGalleryApp** scheme and run on **My Mac** or an iOS Simulator.

## What “available” means at runtime

Metal availability is checked at runtime. A successful build does not guarantee an interactive GPU path.

The app uses Metal when all of these are true:

- the platform supports MetalKit;
- `MTLCreateSystemDefaultDevice()` returns a device;
- the SwiftUI app can host an `MTKView`;
- the user has not disabled the **Use Metal** switch.

If Metal is unavailable, the app falls back to the SwiftUI frame view. Tests also inject unavailable Metal states to keep that path covered.

## How to verify this project’s Metal path

Use focused checks; effect/CLI tests do not prove drawable-backed rendering.

```sh
swift test --filter TTFXSwiftUITests
swift test --filter TTFXGalleryAppTests
swift build --product TTFXGalleryApp
swift build --product TTFXVideoCapture
```

For real visual validation, launch the app:

```sh
./script/build_and_run.sh --verify
```

Then check:

1. `print` and `wipe` show visible glyphs, not a black rectangle.
2. The status says `Metal renderer available` when Metal is active.
3. **Use Metal** OFF shows the SwiftUI fallback.
4. **Use Metal** ON returns to the GPU preview without resetting the effect.

For video export:

```sh
./tools/video-comparison/capture.sh --effect print --max-frames 120
./script/build_and_run.sh --compare
```

The comparison library will include:

- `rust.mp4` — Rust ANSI output replayed through CoreText/Menlo;
- `swiftui.mp4` — SwiftUI fallback rendering;
- `metal.mp4` — Swift effect frames rendered through the Metal atlas/shader path.

## Limits and caveats

- Metal is Apple-platform specific. Linux CI cannot validate real drawable presentation.
- Headless tests prove planning, packing, fallback behavior, and some conditional GPU seams; they do not prove what a user sees in a window.
- Metal rendering is not the behavioral oracle. Rust/TTE parity is checked at the frame/effect level before rendering.
- Font rasterization can differ between Rust terminal replay, SwiftUI text, and the Metal glyph atlas.
- If `GlyphCell.metal`, atlas geometry, cell size, or coordinate mapping changes, repeat both focused tests and a manual app check.

## Mental model

Think of the stack like this:

```text
TTE behavior
  ↓ ported to Rust ttfx
Rust parity oracle
  ↓ ported to Swift core/effects
TTFXFrameSnapshot
  ↓ rendered by one of three surfaces
SwiftUI fallback | Metal GPU preview/export | Rust ANSI replay for comparison
```

Metal is the native GPU surface for the Swift port. It makes the app and visual comparison useful, but it does not decide what an effect is supposed to do.
