# Native cross-platform Swift CLI

## Objective and scope
Implement docs/swift-port/cross-platform-cli-spec.md using native Swift, reusing Core/Effects, preserving graphical products. Rust is a test oracle only. No remote execution, push, PR creation, or merge is authorized.

## Baseline and decisions
- Rust reference: 0f24d88408c8b815761c2c07da7dc9b411f63016.
- Strict TDD: enabled by explicit user request, supplied instructions and openspec/config.yaml. Runner: swift test; Rust oracle runner: cargo test. Record observed RED, GREEN, REFACTOR per behavior.
- RDD: off globally (observed); ordinary functional checks only.
- Delivery: ask-on-risk, resolved chain strategy stacked-to-main. Local work-unit commits form sequential independent slices; remote delivery remains user-owned.
- Forecast: 3,000–6,000 authored changed lines excluding generated fixtures; approximately 400 lines per review slice. Never compress code or omit tests for the budget.
- Local host: macOS arm64, Swift 6.3.3. Windows/Linux execution remains pending until actual hosts are available.

## Tasks and acceptance
- [ ] T01: Isolate CLI-only build/test graph without duplicating engine or breaking graphical graph. Structural regression test; CLI build and focused tests. First slice: graph separation only; portable oracle harness may land separately.
- [ ] T02: Portable oracle harness and strict input/parser/error/filter/help/completion semantics. Subprocess stdout/stderr/status comparisons against reference.
- [ ] T03: Input preprocessing, dimensions, Unicode scalars, wrapping/anchors/clipping and ANSI foreground/background serialization. Unit and Rust byte comparisons.
- [ ] T04: Entropy, shared continuation RNG, deterministic random selection and hidden modes including M0 and zero frame limits. Multi-seed complete sequence comparisons.
- [ ] T05: Injectable clocks, repaint/pacing/teardown runtime. Fake adapter tests and real pacing smoke check.
- [ ] T06: POSIX cancellation, broken pipes and settled resize. PTY lifecycle regressions.
- [ ] T07: Windows console capability, restoration/cancellation/resize/Unicode/redirected handles. Native checks pending host availability.
- [ ] T08: All 37 effects full default/non-default parity corpus, three-OS CI definitions, setup documentation and honest platform evidence. Report any mismatches independently from CLI parity.

## Progress and verification
No implementation yet. Exploration completed; no builds/tests observed. No blanket parity claims permitted. User's untracked specification is preserved, not silently included in commits.

## Slice evidence
Branch point: 0f24d88408c8b815761c2c07da7dc9b411f63016. Running authored count: 0. Record commits, focused checks, runtime scenario, rollback boundaries and slice bases as work completes.

## Next step
Implement T01 with observed RED before manifest changes, using locally cached dependencies. Establish exact CLI-only runner and read back the graphical manifest separately. Then update this document and its Engram mirror before T02.
