# swiftui-renderer Specification (Optional)

## Purpose

Optional SwiftUI-compatible renderer and interactive demo/gallery application using Metal backend driven by TTFXCore frames.

## Requirements

### Requirement: TTFXView Component

The system MAY provide a `TTFXView` (UIViewRepresentable/NSViewRepresentable) that accepts an Effect, text, config, font, seed and renders live using CAMetalLayer + CADisplayLink.

#### Scenario: Live Rendering

- GIVEN configured TTFXView with effect and text
- WHEN added to SwiftUI view hierarchy
- THEN it drives the engine at target FPS, renders glyphs via Core Text atlas to Metal texture, and displays with correct sRGB colors

#### Scenario: Gallery and Playground

- GIVEN demo app
- WHEN launched
- THEN provides gallery of all implemented effects with thumbnails and interactive playground for editing parameters

### Requirement: Performance and Snapshots

Renderer SHALL meet budgets (<4ms frame time) and have deterministic offscreen snapshot tests for CI.

#### Scenario: Atlas and Pipeline

- GIVEN glyph atlas and instanced Metal pipeline
- WHEN rendering frame
- THEN single draw call per frame, zero per-tick allocations, atlas grows bounded to ~4MB

**Note**: This capability is optional. Core parity (swift-ttfx-core, effects, CLI, harness) MUST be completed first. If included, it does not affect byte-identical frame requirements.
