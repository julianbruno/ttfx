# Video Comparison SwiftUI Track

## Goal
Add SwiftUI-rendered effect videos to TTFX Video Comparison and let the app hide that pane so reviewers can focus on Swift Metal.

## Tasks
- [x] Explore current comparison manifest, capture pipeline, player, and UI layout.
- [x] Extend comparison data/playback to support an optional SwiftUI video track while preserving old two-track libraries.
- [x] Capture SwiftUI-rendered videos from native effect frames and document the new artifact.
- [x] Add UI control to show/hide SwiftUI, default visible when present, and keep Metal-only review one click away.
- [ ] Run focused comparison tests and build checks; then commit/push if checks allow.

## Evidence
- `swift test --filter TTFXComparisonTests`: passed (6 tests).
- `swift build --product TTFXVideoCapture && swift build --product TTFXComparisonApp`: passed.
- `.build/debug/TTFXVideoCapture --effect print --max-frames 2 --output /tmp/ttfx-swiftui-capture-test`: passed and produced Rust/SwiftUI/Metal tracks.
