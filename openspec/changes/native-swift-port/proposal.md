# Proposal: Native Swift Port of ttfx

## Intent

Create a complete native Swift version (macOS first) of ttfx that maintains total fidelity — producing byte-identical frames to the current Rust binary for the same input, configuration, and seed. This addresses the desire for deeper Apple platform integration (SwiftUI renderer, native CLI performance on macOS, SPM distribution) while preserving the proven parity and speed characteristics of the existing Rust implementation.

## Scope

### In Scope
- Full port of animation engine (Canvas, Frame, Easing, Geometry, Gradient, RNG with reproducible parity)
- Complete implementation of all 37 effects with byte-identical output
- CLI supporting the same terminal options, effect options, --random-effect, completions, and TTFXANSI rendering
- Parity harness that mechanically validates frame and terminal streams against the Rust binary
- Incremental waves: foundations+parity, base effects, full CLI, optional SwiftUI demo/gallery, release
- Review budget of ~10000 lines managed via chained/auto-chained PRs

### Out of Scope
- Linux/Windows support in initial release (macOS-first)
- Python-style plugin system
- Behavioral changes or "improvements" to upstream quirks (exact reproduction required for parity)
- Non-Swift backends or unified multi-language build

## Capabilities

### New Capabilities
- swift-ttfx-core: Animation engine, core types (Canvas/Frame), utilities (Easing/Geometry/Gradient), reproducible RNG for parity
- swift-effects-parity: All 37 effects with exact frame output matching Rust binary (grouped for spec but implemented incrementally)
- swift-cli: Full command-line interface, argument parsing, ANSI output, terminal options, and TTFXANSI support
- parity-harness: Automated validation suite comparing byte streams, frames, and CLI behavior against Rust reference
- swiftui-renderer: (optional) SwiftUI-based renderer and interactive gallery demo app

### Modified Capabilities
None (new parallel implementation; Rust version remains untouched)

## Approach

Follow the Rust port's structure and parity-first philosophy but in idiomatic Swift.
- Use `swift-argument-parser` for CLI parity.
- Reproduce exact algorithms, rounding behaviors, ordering, and quirks from the Rust (and upstream Python) implementation.
- Implement a test harness using XCTest that invokes the Rust binary as oracle for frame-by-frame and full TTY stream comparison.
- Wave-based delivery: 1) core types + RNG + parity harness, 2) effects by complexity groups, 3) CLI integration, 4) SwiftUI layer.
- SPM package for easy integration. Use value types where possible for performance, classes for effect state machines.

Reference: existing Rust `src/` for logic, `tools/parity/` for test strategy, and original TTE for conceptual design.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Sources/ttfx-swift/` | New | New Swift package containing engine, effects, CLI |
| `Tests/ttfx-swiftTests/` | New | Parity harness, golden tests, effect unit tests |
| `Package.swift` | Modified | Add Swift library and executable targets |
| `openspec/changes/native-swift-port/` | New | SDD artifacts for this change |
| `docs/swift-port/` | New | Parity notes, architecture decisions, benchmark comparisons |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Floating-point/RNG/rounding differences breaking parity | High | Parity harness runs on every effect/config/seed; pin exact math ops and use same PRNG where possible (swap for tests) |
| Review fatigue from 10k LOC port | High | Strict wave slicing into autonomous PRs (<400 lines each where possible); foundations first; use chained PRs |
| Performance regression vs Rust | Medium | Early benchmarking against Rust; focus on hot paths (canvas updates, effect iterators); profile with Instruments |
| Maintaining two implementations long-term | Medium | Document as "Swift port for macOS ecosystem"; decide post-release whether to deprecate Rust version |

## Rollback Plan

- Rust binary remains the default/production implementation and is untouched by this change.
- Develop in a dedicated `ttfx-swift` SPM package or subdirectory; integration into main binary is last step.
- If parity cannot be achieved within budget or performance is unacceptable, merge only the parity harness as a validation tool and abort the port. No runtime impact on existing `ttfx`.

## Dependencies

- Swift 6.0+ (for language features and concurrency if needed)
- `swift-argument-parser` (for CLI parity with existing options)
- Access to existing Rust binary for parity oracle during development

## Success Criteria

- [ ] Parity harness passes for all 37 effects across representative inputs, configs, and seeds (byte-identical frames + TTY streams)
- [ ] `ttfx-swift` CLI produces identical behavior and output to Rust `ttfx`
- [ ] Core engine and effects are fully covered by tests with <5% deviation in benchmark FPS
- [ ] SwiftUI gallery (if included) demonstrates all effects interactively
- [ ] Change delivered via chained PRs respecting 400-line review budget per slice
- [ ] Documentation and build instructions updated; `./bin/test` extended to cover Swift side

**Waves**
1. Foundations + Parity harness
2. Base effects (incremental)
3. Complete CLI
4. SwiftUI + Demo (optional)
5. Release & integration

**Delivery**: Single logical PR (auto-chain slices if needed per review guard)
**Artifacts**: openspec
**Next**: sdd-spec
