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
Resumed branch: codex/native-terminal-runtime. Branch point: 7eb558f. Original Rust oracle reference remains 0f24d88408c8b815761c2c07da7dc9b411f63016. Running authored count: 415 (T01 + partial T02/T04). Record commits, focused checks, runtime scenario, rollback boundaries and slice bases as work completes.

## T01 evidence
- Implementation: `TTFX_CLI_ONLY=1` filters the existing manifest declarations to two products (`ttfx`, `ttfx-swift`) and six shared CLI/Core/Effects targets including their tests. No engine duplication or extra dependency. Normal/unset/`0` keeps the GUI graph.
- RED: `TTFX_CLI_ONLY=1 swift test --filter PackageGraphTests` ran 2 tests; normal graph passed, CLI-only graph failed with 2 assertions (graphical targets/products present). Initial harness stalled on nested SwiftPM's shared build lock; isolated temporary scratch paths resolved that environmental harness issue before meaningful RED.
- GREEN: `TTFX_CLI_ONLY=1 swift package describe --type json` passed; `TTFX_CLI_ONLY=1 swift build --product ttfx` passed (0.17 s); focused graph tests passed 2/2 (0.925 s); normal `swift build --product TTFXComparisonApp` passed (0.64 s).
- REFACTOR: explicit executable lookup failure removed a Swift Testing macro warning; isolated scratch paths retain independent graph inspection. Re-ran focused tests: 2/2 passed, zero skips (0.165 s). `git diff --check` passed.
- Runtime harness: N/A; T01 changes graph selection only, not terminal/runtime behavior.
- Rollback: remove the environment filter/Foundation import from `Package.swift`, `PackageGraphTests.swift`, and the CLI-only documentation section; no engine/GUI behavior is altered.
- Host evidence: macOS arm64 only. Native Ubuntu/Windows builds and full unfiltered oracle suites remain pending T02/T08.
- Work-unit commit: 0741766cd5375952cb040ad6c46119bb37b2ad3e. Parent structural readback/diff check passed. RDD off; risk assessment unavailable (untracked inventory declaration), conservatively high for independent verification; no native review started.

## T02/T04 bounded random/oracle slice (partial)
- Scope: Foundation oracle runner on macOS/Linux/Windows desktop guards, portable PATH/PATHEXT lookup and git/cargo resolution, file-backed input preventing unread-large-stdin pipe deadlock. No remote or external runtime dependency. Existing Apple/mobile unsupported guard remains appropriate for subprocess-only test tooling.
- Random CLI now renders rather than printing a pending message. Omitted seed uses Swift native system entropy through an injectable selection boundary. Explicit seed is evaluated without entropy. Filtering preserves registry order; random selection ignores effect-specific settings. Optional initial Xoshiro snapshot is passed to all effect RNG constructors (including precomputed Beams/Smoke helpers), so selection/rejection draws are retained instead of reseeding. Ordinary configuration remains source-compatible and defaults to the same fresh seeded stream.
- RED: before implementation, portable-runner structural regression failed; 37 singleton oracle cases yielded seeded RNG mismatches, observed suite failure (22 issues overall). Original multi-candidate test used unsupported comma syntax and was corrected to individual values; those four error results are harness errors, not selection evidence. Meaningful singleton/runner assertion failures are the RED of record.
- GREEN: `TTFX_CLI_ONLY=1 swift build --product ttfx` passed (1.38 s after correcting Smoke helper scope compilation). Initial oracle run exposed an independent pre-existing `errorcorrect` edge case: 8-character input -> Rust zero frames, Swift one frame. Scope remains partial; no silent parity certification.
- Final sequential checks: `TTFX_CLI_ONLY=1 swift test --filter 'ProcessRunnerTests|CLIParsingTests|CLIParityDumpTests'` passed 16 test functions in 3 suites, zero skips (5.551 s). `TTFX_CLI_ONLY=1 swift test --filter RandomSelectionTests` passed 5 functions in 2 suites (25.861 s), including all 37 singleton candidates on recorded comparison input, four multi-candidate seeds 0/7/42/123, injectable entropy, and both runner checks. Oracle cases use 12-frame cap and virtual clock, not complete-sequence certification.
- Runtime smoke: `printf 'Swift' | .build/debug/ttfx --seed 42 --random-effect --include-effects print` completed, 2,477 output bytes, placeholder absent. Real terminal lifecycle/pacing remains pending T05–T07.
- REFACTOR: central shared configuration RNG helper, PATH rather than hardcoded `/usr/bin/env` or git paths in focused harness, Windows executable suffix/case-insensitive environment lookup, file-backed input; no extra library and no global RNG mutation. Final normalized `TTFX_CLI_ONLY=1 swift build --product ttfx` passed (0.65 s); `TTFX_CLI_ONLY=1 swift test --filter ProcessRunnerTests` passed 2/2 functions, zero skips (0.140 s). `git diff --check` passed.
- Pending: full input/parser/error/completion compatibility T02; M0/zero-cap and resize RNG checkpoints T04; small-input no-pair `errorcorrect` mismatch and complete corpus T08; actual Ubuntu/Windows runs. Do not check T02/T04 off.
- Rollback: revert random selection/RNG snapshot/helper wiring, portable runner/focused harness tests, and associated docs together; engine algorithms and ordinary seeded behavior are not changed.
- Work-unit commit: pending parent verification/commit. RDD off.

## Next step
Parent verifies and commits the bounded T02/T04 slice, recording identity/count and final runner build proof. Continue terminal runtime/adapters T05–T07 with strict TDD; resizing requires a public current RNG checkpoint/continuation boundary, since this slice only provides initial state. Keep full T02/T04/T08 acceptance pending.

Partial T02/T04 work-unit commit: 20ced14faa477ed83b5abbeb2bdca986ca96406d. Parent structural readback and diff check passed. Native review disabled; independent aggregate verification follows runtime work.

## T05/T06 first runtime slice (partial)
- Added injectable monotonic clock and byte sink; normal CLI canvas hide/allocation/save, restore/save/up repaint, frame pacing including first frame, single teardown respecting reuse/no-eol/no-restore flags. Testing helper now executes the full normal stream using virtual pacing; hidden dump bytes remain unchanged.
- Native POSIX partial-write/EINTR loop, SIGPIPE ignore/quiet early or frame-write EPIPE, SIGINT flag/cleanup/status 1, TTY-only SIGTERM cleanup/default/re-raise, saved signal disposition restoration. Signal callbacks only write a `sig_atomic_t` flag. Cancellation is checked after effect tick and after frame pacing before painting.
- RED: initial `TerminalRuntimeTests` lifecycle regression failed 2 assertions against prior raw frame stream. Cancellation-during-pacing behavioral RED emitted 13 bytes instead of empty; then guarded output after pacing. Compiler cache sandbox failures, absent seam compile failure, and an uninitialized ArgumentParser test default were environmental/harness failures, not behavioral RED.
- Native smoke discovered SIG_DFL is a nil optional `sig_t` on Darwin; saved dispositions now explicitly optional, preventing an initial native SIGTRAP. Broken-pipe smoke then failed noisy prepare error; catching EPIPE during preparation fixed that boundary too.
- GREEN: 5 TerminalRuntimeTests functions; focused CLIParityDumpTests isolated passed 2 functions including print/wipe/expand and all 37 framed exports (5.757 s). Combined required parser/parity/random command ran 19 functions; one oracle expand subprocess was killed with status 9, while parser/37 random singleton/four multi-seed cases passed. Isolated oracle rerun passed; retain combined failure rather than inventing proof. Normal comparison app build passed (1.68 s); CLI build passed.
- Runtime harness: `python3 tools/swift-parity/terminal-smoke.py` exact full Rust/Swift redirected print transcript for recorded input, seed42/canvas24×8; real10fps runtime ~4.6s; SIGINT cursor/status1 and SIGTERM cursor/signal-15, empty stderr; early broken-pipe quiet status0. PTY cancellation/pacing observed on macOS only.
- Pending: dimensions/layout/color/input strict semantics, effect real clocks, current RNG resize continuation and settled resize, Windows native adapter/host proof. T05/T06 remain unchecked until full acceptance. Tiny `Hi` inferred2×1 Print exposes pre-existing effect glyph/color mismatch (18 frames both, Swift1089 vs Rust1074 bytes); no silent certification.
- REFACTOR: small clock/runtime/native-write boundaries, single normal cancellation teardown, optional native signal disposition restoration; no effect rewrites and no GUI changes. Final focused tests/smoke/diff check recorded by writer handoff.
- Rollback: runtime/NativeTerminal files, normal CLI integration, TerminalRuntimeTests, terminal-smoke.py, native-terminal-runtime.md together; hidden export/engine/GUI remain intact.
- Work-unit commit: pending parent verification/commit; RDD off.
