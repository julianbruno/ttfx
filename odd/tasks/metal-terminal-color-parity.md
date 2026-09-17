# Metal Terminal Color Parity

## Objective / Problem
Fix Metal white backgrounds in overflow by preserving Rust terminal color semantics. Renderer currently masks explicit-black metadata sentinel into RGB white.

## Authorized scope / Constraints
Metal cell upload/color semantics, regression tests, local video regeneration, verification evidence. Preserve unrelated docs/swift-port/cross-platform-cli-spec.md. No remote/push. Strict TDD enabled from user workflow/AGENTS; runner swift test. RDD off globally. Delivery ask-on-risk, forecast ~100 authored changed lines. Continue existing feature branch codex/swiftui-rust-render-parity.

## Tasks
- [x] M01 Reproduce sentinel/default-white Metal bug with failing tests, fix color upload semantics, verify focused SwiftUI/comparison tests and full serial suite; conventional work-unit commit.
- [ ] M02 Regenerate affected local Metal videos (all library if practical); verify overflow and sentinel-affected effects against Rust. Record proof and conventional work-unit commit.

## Acceptance / Checks
Sentinel 0xFFFF_FFFE is metadata, never visible RGB. Default fg0 white; explicit black fg0 stays black; genuine background RGB preserved. Production Metal GPU output black empty regions and correct glyphs. Commands swift test --filter 'TTFXSwiftUITests|TTFXComparisonTests'; swift test --no-parallel; local capture+ffprobe+representative decoded frame comparison.

## Progress / Evidence
- Root cause: raw upload masked sentinel 0xFFFF_FFFE into #FFFFFE instead of interpreting explicit-black foreground metadata.
- RED: `swift test --filter 'metalUploadResolves|metalGPURendersExplicit'` failed 2 tests with 746 assertions before fix, including production GPU white boxes and missing default-white glyph.
- GREEN: `swift test --filter 'TTFXSwiftUITests|TTFXComparisonTests'` passed 27 tests.
- REFACTOR: aggregated GPU pixel mismatch counts for concise failures; kept color resolution at the upload boundary without altering effects.
- `swift test --no-parallel` passed 200 tests in 5 suites (120.130 seconds), including mandatory genuine-GPU regression.
- Runtime coverage: explicit black glyph+space regions all black; default-white glyph coverage >25 pixels; genuine #112233 background exact BGRA preserved.
- Rollback: remove scoped upload color resolution and 2 regression tests; effect engine unchanged.
- M01 work-unit commit: pending creation.

## Next step
M02 regenerate all 37 effects/111 local videos, then check metadata and sampled Rust/Metal output. Unrelated cross-platform CLI spec remains untouched.


