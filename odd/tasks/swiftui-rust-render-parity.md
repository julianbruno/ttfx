# SwiftUI / Rust Render Parity

## Objective
Match the production SwiftUI fallback and exported comparison videos to Rust terminal rendering: glyph scale, fixed-grid placement, foreground and background colors.

## Problem / Why
SwiftUI currently renders plain intrinsic-size lines instead of the snapshot's colored terminal cells.

## Authorized scope
SwiftUI fallback renderer, capture metrics, regression tests, comparison docs, regenerated local comparison videos. No remote operations or push.

## Constraints
English artifacts. Strict TDD enabled by explicit user request and AGENTS.md: observed RED → GREEN → REFACTOR. Runner: swift test. RDD off (global). Delivery strategy ask-on-risk. Forecast ~250 authored changed lines; generated videos excluded.

## Tasks
- [x] T01 Fix production grid renderer and capture metrics with pixel-level regression tests; update docs. Checks: swift test --filter 'TTFXSwiftUITests|TTFXComparisonTests|TTFXGalleryAppTests'; swift test --no-parallel. Record RED/GREEN and work-unit commit.
- [x] T03 Preserve Rust terminal default-white and explicit-black sentinel semantics with RED/GREEN pixel regressions; rerun focused and serial suites.
- [ ] T02 Regenerate local comparison videos; verify dimensions, frames and representative visual output against Rust. Record runtime evidence and work-unit commit for tracked evidence.

## Acceptance
SwiftUI preserves each cell's foreground/background, blank backgrounds, grid coordinates, Menlo glyph size and canvas placement matching Rust export. Gallery fallback remains usable. Videos use genuine SwiftUI rendering, not copied Rust/Metal pixels.

## Progress / Evidence
Exploration confirmed plain Text lines drop colors and ignore export cell metrics. Branch codex/swiftui-rust-render-parity. Working tree initially clean.

### T01 evidence
- RED: `swift test --filter swiftUIReplay` failed 2 tests with 7 assertion failures (discarded foreground/background, wrong glyph bounds).
- GREEN: same focused command passed 3 pixel tests after fixed-cell SwiftUI Canvas implementation.
- REFACTOR: shared gallery fallback composition; removed obsolete plain-text renderer; focused required suite passed 43 tests.
- `swift test --no-parallel`: 197 tests in 5 suites passed (112.342 seconds).
- Environment: initial sandbox-only SwiftPM attempt could not write toolchain module cache; rerun with approved local escalation succeeded.
- Runtime boundary: ImageRenderer regression pixels compared to independent Rust ANSI/CoreText replay, including colored blank cells, bottom-row placement, Menlo glyph bounds, mixed RGB and Unicode.
- Rollback: revert scoped renderer/gallery/exporter/test/docs changes; effect engine remains unchanged.
- Work-unit commit: `12a3d48`. Independent verification: 3 pixel tests passed; no blocking finding.

### T03 evidence
- RED: `swift test --filter swiftUIReplayDistinguishes` failed 1 pixel comparison before sentinel correction.
- GREEN: sentinel/default-white regression matches independent ANSI/CoreText BGRA bytes exactly; focused required suite passed 44 tests.
- REFACTOR: kept resolution local to SwiftUI cell drawing without changing effect storage or Metal.
- `swift test --no-parallel`: 198 tests in 5 suites passed (112.920 seconds).
- Runtime: T02 initial regeneration exposed white rectangles in beams frame 50; fix addresses the exact sentinel cause. Final regenerated proof pending.
- Rollback: revert terminal color resolution, its regression test and recording-doc sentence only.
- Work-unit commit: pending creation.

## Next step
T02 regenerate all 37 effects after T03, verify all 111 video metadata records and sample first/middle/final Rust/SwiftUI frames.




### Accepted T03 discovery
13 effects encode explicit-black foreground with background sentinel 0xFFFF_FFFE. Raw RGB rendering incorrectly painted white backgrounds; ordinary foreground zero must resolve to terminal default white. Fix SwiftUI only; Metal discrepancy is a separate limitation. T02 remains pending until regenerated after correction.
