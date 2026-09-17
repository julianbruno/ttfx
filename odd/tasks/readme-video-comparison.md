# README video comparison update

## Goal
Explain the Swift port as a work-in-progress port of the Rust port, show how to produce real SwiftUI/Metal/Rust comparison evidence, and diagnose the `manifest.json` loading failure.

## Tasks

- [x] Explore README, comparison docs, launch scripts, generated artifact layout, and current failure shape.
  - Evidence: README.md, docs/swift-port/video-comparison.md, script/run_comparison.sh, artifacts/video-comparison/manifest.json inspected.
- [x] Make the comparison app's default library lookup robust enough for Xcode/direct launches.
  - Evidence: added repository-root fallback from build directories and a clearer missing-manifest error; focused tests pending.
- [x] Update README with the WIP port lineage, concrete SwiftUI/video comparison examples, and manifest troubleshooting.
  - Evidence: README now explains Python → Rust → Swift lineage, native app workflows, generated comparison artifact paths, and `manifest.json` recovery.
- [x] Verify the README/app change and report status without committing unless explicitly requested.
  - Evidence: `swift test --filter TTFXComparisonTests` passed 11 tests; `swift build --product TTFXComparisonApp` passed; `./script/build_and_run.sh --compare --verify` passed.
- [x] Put the optional SwiftUI video pane on the right and document the three-pane layout.
  - Evidence: `swift build --product TTFXComparisonApp` passed; `swift test --filter TTFXComparisonTests` passed 11 tests.
- [x] Diagnose and fix the linked macOS CI failure.
  - Evidence: GitHub job failed compiling `Sources/ttfx-swift/SwiftUI/MetalGlyphAtlas.swift` on Swift 6.2.1 with ambiguous `+` between `Double` and `CGFloat`; explicit `CGFloat` casts added; `swift build --product TTFXGalleryApp` and `swift test --filter TTFXSwiftUITests` passed locally.
