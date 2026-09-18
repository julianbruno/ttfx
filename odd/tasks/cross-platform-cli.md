# Native cross-platform Swift CLI

## Objective and scope
Implement docs/swift-port/cross-platform-cli-spec.md using native Swift, reusing Core/Effects, preserving graphical products. Rust is a test oracle only. No remote execution, push, PR creation, or merge is authorized.

## Baseline and decisions
- Rust reference: 0f24d88408c8b815761c2c07da7dc9b411f63016.
- Strict TDD: enabled by explicit user request, supplied instructions and openspec/config.yaml. Runner: swift test; CLI-only runner for T01: TTFX_CLI_ONLY=1 swift test --filter PackageGraphTests; Rust oracle runner: cargo test. Record observed RED, GREEN, REFACTOR per behavior.
- RDD: off globally (observed); ordinary functional checks only.
- Delivery: ask-on-risk, resolved chain strategy stacked-to-main. Local work-unit commits form sequential independent slices; remote delivery remains user-owned.
- Forecast: 3,000–6,000 authored changed lines excluding generated fixtures; approximately 400 lines per review slice. Never compress code or omit tests for the budget.
- Local host: macOS arm64, Swift 6.3.3. Windows/Linux execution remains pending until actual hosts are available.

## Tasks and acceptance
- [x] T01: Isolate CLI-only build/test graph without duplicating engine or breaking graphical graph. Structural regression test; CLI build and focused tests. First slice: graph separation only; portable oracle harness may land separately.
- [ ] T02: Portable oracle harness and strict input/parser/error/filter/help/completion semantics. Subprocess stdout/stderr/status comparisons against reference.
- [ ] T03: Input preprocessing, dimensions, Unicode scalars, wrapping/anchors/clipping and ANSI foreground/background serialization. Unit and Rust byte comparisons.
- [ ] T04: Entropy, shared continuation RNG, deterministic random selection and hidden modes including M0 and zero frame limits. Multi-seed complete sequence comparisons.
- [ ] T05: Injectable clocks, repaint/pacing/teardown runtime. Fake adapter tests and real pacing smoke check.
- [ ] T06: POSIX cancellation, broken pipes and settled resize. PTY lifecycle regressions.
- [ ] T07: Windows console capability, restoration/cancellation/resize/Unicode/redirected handles. Native checks pending host availability.
- [ ] T08: All 37 effects full default/non-default parity corpus, three-OS CI definitions, setup documentation and honest platform evidence. Report any mismatches independently from CLI parity.

## Progress and verification
Resumed 2026-09-17 after explicit user authorization to implement the identified native CLI gaps. Scope includes package isolation, portable oracle/input semantics, random selection/entropy, terminal repaint/pacing, POSIX and Windows adapters, and honest three-platform checks. Existing effects and GUI products must remain intact. The full non-default specification corpus is not yet implemented or certified. T01 is the first bounded slice; T02–T08 remain pending.

## Slice evidence
Resumed branch: codex/native-terminal-runtime. Branch point: 7eb558f. Original Rust oracle reference remains 0f24d88408c8b815761c2c07da7dc9b411f63016. Running authored count: 0. Record commits, focused checks, runtime scenario, rollback boundaries and slice bases as work completes.

## T01 evidence
- Implementation: `TTFX_CLI_ONLY=1` filters the existing manifest declarations to two products (`ttfx`, `ttfx-swift`) and six shared CLI/Core/Effects targets including their tests. No engine duplication or extra dependency. Normal/unset/`0` keeps the GUI graph.
- RED: `TTFX_CLI_ONLY=1 swift test --filter PackageGraphTests` ran 2 tests; normal graph passed, CLI-only graph failed with 2 assertions (graphical targets/products present). Initial harness stalled on nested SwiftPM's shared build lock; isolated temporary scratch paths resolved that environmental harness issue before meaningful RED.
- GREEN: `TTFX_CLI_ONLY=1 swift package describe --type json` passed; `TTFX_CLI_ONLY=1 swift build --product ttfx` passed (0.17 s); focused graph tests passed 2/2 (0.925 s); normal `swift build --product TTFXComparisonApp` passed (0.64 s).
- REFACTOR: explicit executable lookup failure removed a Swift Testing macro warning; isolated scratch paths retain independent graph inspection. Re-ran focused tests: 2/2 passed, zero skips (0.165 s). `git diff --check` passed.
- Runtime harness: N/A; T01 changes graph selection only, not terminal/runtime behavior.
- Rollback: remove the environment filter/Foundation import from `Package.swift`, `PackageGraphTests.swift`, and the CLI-only documentation section; no engine/GUI behavior is altered.
- Host evidence: macOS arm64 only. Native Ubuntu/Windows builds and full unfiltered oracle suites remain pending T02/T08.
- Work-unit commit: pending parent readback/commit. RDD off; assessment/review N/A until parent records ordinary verification.

## Next step
Parent verifies and commits T01, recording the commit identity and authored count in this document and full Engram mirror. Continue T02–T08 in bounded slices; graph isolation alone does not complete the runtime or full specification corpus.
