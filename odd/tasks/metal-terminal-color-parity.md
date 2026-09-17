# Metal Terminal Color Parity

## Objective / Problem
Fix Metal white backgrounds in overflow by preserving Rust terminal color semantics. Renderer currently masks explicit-black metadata sentinel into RGB white.

## Authorized scope / Constraints
Metal cell upload/color semantics, regression tests, local video regeneration, verification evidence. Preserve unrelated docs/swift-port/cross-platform-cli-spec.md. No remote/push. Strict TDD enabled from user workflow/AGENTS; runner swift test. RDD off globally. Delivery ask-on-risk, forecast ~100 authored changed lines. Continue existing feature branch codex/swiftui-rust-render-parity.

## Tasks
- [x] M01 Reproduce sentinel/default-white Metal bug with failing tests, fix color upload semantics, verify focused SwiftUI/comparison tests and full serial suite; conventional work-unit commit.
- [x] M02 Regenerate affected local Metal videos (all library if practical); verify overflow and sentinel-affected effects against Rust. Record proof and conventional work-unit commit.

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
- M01 work-unit commit: `0874fc6`. Independent verifier: 2 focused regressions passed, including genuine GPU; no blocker.

### M02 evidence
- `.build/debug/TTFXVideoCapture` regenerated all 37 effects/111 videos with genuine GPU; all effects complete.
- Every video's ffprobe metadata matched manifest: 384 × 192, 25 FPS, exact frame count.
- Decoded first/middle/final Rust/Metal RGB frames for all 37 effects (111 samples). Maximum mean absolute RGB error 8.75/255 (synthgrid frame 192); overflow final frame 18 error 2.3609/255.
- Metal atlas rasterization differs intentionally from terminal replay: Menlo 44 in 40 × 56 slots rescaled/bilinear-sampled versus Rust Menlo 20 CoreText. These glyph-coverage residuals are not a byte-identical-video claim; atlas changes outside white-background bug scope.
- Black-cell verification across all samples: 18530 Rust-black grid cells checked; 0 bright Metal background mismatches (Rust mean RGB <1; Metal mismatch threshold >20).
- Parent and worker inspected final overflow contact sheet; white backgrounds gone, placement/colors retained.
- Local ignored proof: `artifacts/video-comparison/metal-parity-overflow.png` (Rust/Metal/SwiftUI), `metal-parity-check.json` (metadata/sample/background metrics).
- Rollback: regeneration from previous renderer replaces ignored videos; tracked proof can be reverted independently.
- M02 work-unit commit: `a0d708b`.
- RDD off globally; no review lifecycle/remote/push/PR operations. Unrelated `docs/swift-port/cross-platform-cli-spec.md` untouched.

## Next step
Parent final task mirror synchronization and verification readback; implementation complete.
