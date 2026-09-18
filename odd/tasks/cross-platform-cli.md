# Native cross-platform Swift CLI

## Objective and scope
Implement docs/swift-port/cross-platform-cli-spec.md using native Swift, reusing Core/Effects, preserving graphical products. Rust is a test oracle only. The user subsequently authorized documentation updates and pushing all new commits on `codex/native-terminal-runtime` to `origin` (`julianbruno/ttfx`) using the previously confirmed SSH configuration. No manual CI trigger, other remote execution, PR creation or merge is authorized.

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
- [x] T05: Injectable clocks, repaint/pacing/teardown runtime. Fake adapter tests and real pacing smoke check, with local macOS proof.
- [ ] T06: POSIX cancellation, broken pipes and settled resize. PTY lifecycle regressions.
- [ ] T07: Windows console capability, restoration/cancellation/resize/Unicode/redirected handles. Native checks pending host availability.
- [ ] T08: All 37 effects full default/non-default parity corpus, three-OS CI definitions, setup documentation and honest platform evidence. Report any mismatches independently from CLI parity.

## Progress and verification
Resumed 2026-09-17 after explicit user authorization to implement the identified native CLI gaps. Scope includes package isolation, portable oracle/input semantics, random selection/entropy, terminal repaint/pacing, POSIX and Windows adapters, and honest three-platform checks. Existing effects and GUI products must remain intact. The full non-default specification corpus is not yet implemented or certified. T01 and T05 are complete with local macOS proof. T02/T03/T04/T06/T07/T08 remain partial or pending; implemented platform adapters do not certify other hosts.

## Slice evidence
Resumed branch: codex/native-terminal-runtime. Branch point: 7eb558f. Original Rust oracle reference remains 0f24d88408c8b815761c2c07da7dc9b411f63016. Historical first-runtime-slice count: 750 authored lines. Current runtime work-unit count: 1,444 additions + deletions through `6248009`, before evidence-only documentation commits. Record commits, focused checks, runtime scenario, rollback boundaries and slice bases as work completes.

## T01 evidence

The slice sections below preserve observations at implementation time; later final verification and delivery sections supersede their provisional pending statements.
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
- Runtime smoke: `printf 'Swift' | .build/debug/ttfx --seed 42 --random-effect --include-effects print` completed, 2,477 output bytes, placeholder absent. At this historical slice boundary, real terminal lifecycle/pacing remained pending T05–T07; subsequent runtime slices implement it.
- REFACTOR: central shared configuration RNG helper, PATH rather than hardcoded `/usr/bin/env` or git paths in focused harness, Windows executable suffix/case-insensitive environment lookup, file-backed input; no extra library and no global RNG mutation. Final normalized `TTFX_CLI_ONLY=1 swift build --product ttfx` passed (0.65 s); `TTFX_CLI_ONLY=1 swift test --filter ProcessRunnerTests` passed 2/2 functions, zero skips (0.140 s). `git diff --check` passed.
- Pending: full input/parser/error/completion compatibility T02; M0/zero-cap and resize RNG checkpoints T04; small-input no-pair `errorcorrect` mismatch and complete corpus T08; actual Ubuntu/Windows runs. Do not check T02/T04 off.
- Rollback: revert random selection/RNG snapshot/helper wiring, portable runner/focused harness tests, and associated docs together; engine algorithms and ordinary seeded behavior are not changed.
- Work-unit commit: `20ced14` (this slice's original pending entry was resolved after parent verification). RDD off.

## Next step
Close documentation and perform the user-authorized push of `codex/native-terminal-runtime` to `origin`; record the observed outcome without assuming CI PASS. Native Ubuntu/Windows compilation and lifecycle checks, remaining parser/hidden-mode and ANSI-color compatibility, and the full non-default corpus remain pending.

Partial T02/T04 work-unit commit: 20ced14faa477ed83b5abbeb2bdca986ca96406d. Parent structural readback and diff check passed. Native review disabled; independent aggregate verification follows runtime work.

## T05/T06 first runtime slice (partial)
- Added injectable monotonic clock and byte sink; normal CLI canvas hide/allocation/save, restore/save/up repaint, frame pacing including first frame, single teardown respecting reuse/no-eol/no-restore flags. Testing helper now executes the full normal stream using virtual pacing; hidden dump bytes remain unchanged.
- Native POSIX partial-write/EINTR loop, SIGPIPE ignore/quiet early or frame-write EPIPE, SIGINT flag/cleanup/status 1, TTY-only SIGTERM cleanup/default/re-raise, saved signal disposition restoration. Signal callbacks only write a `sig_atomic_t` flag. Cancellation is checked after effect tick and after frame pacing before painting.
- RED: initial `TerminalRuntimeTests` lifecycle regression failed 2 assertions against prior raw frame stream. Cancellation-during-pacing behavioral RED emitted 13 bytes instead of empty; then guarded output after pacing. Compiler cache sandbox failures, absent seam compile failure, and an uninitialized ArgumentParser test default were environmental/harness failures, not behavioral RED.
- Native smoke discovered SIG_DFL is a nil optional `sig_t` on Darwin; saved dispositions now explicitly optional, preventing an initial native SIGTRAP. Broken-pipe smoke then failed noisy prepare error; catching EPIPE during preparation fixed that boundary too.
- GREEN: 5 TerminalRuntimeTests functions; focused CLIParityDumpTests isolated passed 2 functions including print/wipe/expand and all 37 framed exports (5.757 s). Combined required parser/parity/random command ran 19 functions; one oracle expand subprocess was killed with status 9, while parser/37 random singleton/four multi-seed cases passed. Isolated oracle rerun passed; retain combined failure rather than inventing proof. Normal comparison app build passed (1.68 s); CLI build passed.
- Runtime harness: `python3 tools/swift-parity/terminal-smoke.py` exact full Rust/Swift redirected print transcript for recorded input, seed42/canvas24×8; real10fps runtime ~4.6s; SIGINT cursor/status1 and SIGTERM cursor/signal-15, empty stderr; early broken-pipe quiet status0. PTY cancellation/pacing observed on macOS only.
- Pending: dimensions/layout/color/input strict semantics, effect real clocks, current RNG resize continuation and settled resize, Windows native adapter/host proof. At this slice boundary T05/T06 remained unchecked; later combined proof closes T05, while T06 remains partial. Tiny `Hi` inferred2×1 Print exposes pre-existing effect glyph/color mismatch (18 frames both, Swift1089 vs Rust1074 bytes); no silent certification.
- REFACTOR: small clock/runtime/native-write boundaries, single normal cancellation teardown, optional native signal disposition restoration; no effect rewrites and no GUI changes. Final focused tests/smoke/diff check recorded by writer handoff.
- Rollback: runtime/NativeTerminal files, normal CLI integration, TerminalRuntimeTests, terminal-smoke.py, native-terminal-runtime.md together; hidden export/engine/GUI remain intact.
- Work-unit commit: `5b5dad8` (original pending status resolved by parent verification/commit); RDD off.


First T05/T06 runtime work-unit commit: 5b5dad8. Parent structural readback/diff check passed; native review remains disabled.

## T03/T04/T05/T06/T07 second native environment slice (partial)

### Implemented
- Native viewport query, independent COLUMNS/LINES integer overrides, and 80×24 fallback. Positive, zero and -1 canvas sizes remain distinct. Unicode-scalar input widths, wrapping, text/canvas anchors and clipping are supported.
- Strict UTF-8 rejection and fixed-width tab expansion. Interactive stdin exits without waiting for EOF; empty/whitespace normal input exits quietly. Supported input SGR is currently stripped, not preserved by always/dynamic handling.
- No-color and xterm serialization apply to actual frame foreground/background channels, including explicit black foreground. Terminal-background blending remains pending.
- Optional RNGContinuation retains the current Xoshiro stream, including selection, constructor and tick draws. Resize rebuilds consume this continuation rather than the original seed. Ordinary configuration retains independent RNG value semantics.
- Optional EffectClock gives normal CLI Matrix/Thunderstorm monotonic real time; gallery/parity defaults and --virtual-clock retain tick-based timing.
- Terminal stdout polls dimensions, waits a 50 ms quiet window, compares layout, clears the old area and rebuilds with reuse disabled. Redirected output, ignored dimensions and unchanged layouts do not restart.
- Conditional WinSDK adapter preserves/enables/restores console output mode, uses Unicode WriteConsoleW for consoles and UTF-8 WriteFile for redirected handles, retries partial writes, queries viewport size, and handles cooperative Ctrl-C/Break through a preallocated atomic flag. Detached redirected processes do not require a console-control channel. Close/logoff/shutdown leave default OS termination; cursor cleanup is not guaranteed.
- Added .github/workflows/swift-cli.yml with CLI-only builds, portable checks and help on macOS, Ubuntu and Windows. Windows uses the dedicated Windows Swift setup action; macOS/Ubuntu use setup-swift v2. This workflow has not run remotely.

### Verification
- RED: four TerminalLayoutTests failures before implementation: invalid UTF-8 accepted, zero canvas dimension wrong, no-color ignored, and grapheme-count width. Optional environment seams then produced three NativeTerminalPolicyTests issues: current RNG snapshot/rebuild wrong and constant real clock incorrectly completed. Odd-center/trailing-space anchoring failed two assertions before correction. Harness macro and incremental linker failures are excluded from behavioral RED.
- GREEN: final 15 functions in three runtime/layout/policy suites passed, zero skips (0.033 s). Required aggregate parser/parity/random/runner/graph command passed 21 functions in five suites (26.121 s), including 37 random singleton cases and four multi-seed cases. CLI build passed (0.15 s); normal comparison GUI build passed (1.66 s).
- Extended native smoke passed: exact full recorded Rust/Swift Print transcript; real 10 FPS playback (4.622 s); SIGINT status 1 and SIGTERM signal -15 with cursor cleanup and quiet stderr; quiet broken pipe; PTY settled resize from 20×4 to 24×6; redirected SIGWINCH without clear/restart; interactive stdin without EOF blocking. Local macOS evidence only.
- CompleteEffectParityTests ran once after RNG/clock/layout wiring: all 117 recorded cases passed (111 default + six timed), two functions, zero skips, 73.865 s. The subsequent odd/nonspace anchor correction has focused proof and leaves sw/default positions unchanged; the writer did not repeat the expensive corpus at that point; the later independent final run below passed. This is sampled default/timed evidence, not exhaustive non-default parity.
- REFACTOR: forwarding overloads preserve original Canvas.ingest and EffectConfiguration initializer signatures; existing xterm palette is reused; test helper accepts injected dimensions rather than assuming host viewport. Rust and GUI source were not changed. git diff --check passed.

### Remaining and rollback
- Full T02 parser/diagnostic/help/M0/zero-cap semantics; T03 always/dynamic input-color handling and terminal-background mixing; comprehensive non-default effect corpus and known tiny-input mismatches; native Ubuntu/Windows execution and lifecycle proof remain pending. T03/T04/T06/T07/T08 remain unchecked; T05 closes on the combined runtime proof below.
- Windows adapter is implemented but not compiled or exercised on this macOS host. CI definition is not CI PASS.
- Rollback: second-slice TerminalLayout/Core environment/RNG opt-in/Matrix+Thunderstorm clock changes, CLI integration, WinSDK branch, new tests, extended smoke, CI and docs together. Retain the first runtime/pacing slice and GUI products.
- Work-unit commit: `6248009` (original pending status resolved by independent verification/commit). RDD off. Full mirror updated and read back.


## Accepted verification correction
Independent verification reported all runtime/graph checks, parser/parity/random/runner checks, eight PTY smokes, complete 117-case parity, CLI runtime tests and CLI/GUI builds passing. One accepted harness finding: PackageGraphTests looked up the exact PATH key, while Windows can supply Path. Before the bounded fix, add a mixed-case environment regression; then reuse the portable ProcessRunner executable resolver. Recheck graph/runtime/layout/policy suites and CLI build. No effect rewrite or expensive parity rerun is required for this harness-only correction. Update existing docs to distinguish implemented terminal adapters from unverified native Ubuntu/Windows execution; full specification compatibility remains partial.


## Bounded correction and documentation result
- PackageGraphTests mixed-case Path regression observed meaningful RED: executable lookup threw file-not-found while both ordinary graph tests passed. GREEN: reuse ProcessRunner.resolveExecutable with a normalized PATH key; three graph tests and 15 runtime/layout/policy functions passed together (18 functions, four suites, zero skips, 0.160 s). CLI build passed (0.16 s). No effect/Core changes were needed for this correction.
- Updated root README, Swift README and beginner platform guide: original missing runtime features are implemented and macOS-verified; Ubuntu/Windows native compilation and lifecycle are unverified; Rust/WSL remain beginner reference paths; experimental native CLI-only shell/PowerShell build commands are explicitly not tested host results. Official Swift installer/prerequisite documentation was checked; no installer or remote CI was run.
- T05 now checked on observed injectable clock/repaint/pacing/teardown proof. T06 remains partial: local POSIX resize/cancellation smokes pass, but native Ubuntu/reference-wide lifecycle evidence is not certified. T02/T03/T04/T07/T08 remain partial.
- Local Markdown links and git diff --check verified. Conventional commit was subsequently recorded as `6248009`.

## Final delivery of identified runtime gaps
- Work units: T01 `0741766`; random/oracle `20ced14`; paced POSIX runtime `5b5dad8`; layout/resize/WinSDK/context/CI and bounded harness correction `62480092c0d944f049d270cb0db128392187f29b`.
- Running authored work-unit count: 1,444 additions + deletions before final evidence-only commit. Coherent runtime context and platform integration exceed the advisory per-task heuristic; no tests were omitted or code compressed. Existing stacked-to-main delivery preference retained; no PR, push or merge performed.
- Independent macOS verification: initial 17 runtime/layout/policy/graph functions and 19 parser/parity/random/runner functions passed (25.753 s), eight PTY smoke scenarios passed (real pacing 4.597 s), CLI and comparison builds passed, 117 complete default/timed cases plus two CLI runtime functions passed without skips (74.436 s).
- Final independent spot check after the mixed-case Path correction: 18 graph/runtime/layout/policy functions in four suites passed, zero skips (1.093 s). Parent structural readback and git diff --check passed. Writer checked 121 local Markdown links. Guide now explains unsetting TTFX_CLI_ONLY before graphical builds.
- The earlier aggregate oracle subprocess status 9 was not suppressed: subsequent isolated and independent required suites passed. Initial syntax/link/cache/scratch-lock issues were harness/environment failures, not TDD RED.
- T01 and T05 acceptance complete locally. The original identified runtime development is implemented; native Ubuntu/Windows compilation and terminal proof remain unavailable on this Mac. Windows code is conditional source, not a verified binary. Three-OS CI is defined, not run remotely.
- Remaining full specification work: T02 parser/diagnostic/hidden modes, T03 existing ANSI always/dynamic and terminal-background mixing, T04 complete hidden/RNG corpus, T06 reference-wide/Linux lifecycle, T07 Windows host proof, T08 comprehensive non-default corpus and native CI results. Known small-input errorcorrect zero-frame and tiny Print glyph/color mismatches remain explicit follow-ups, not newly certified parity.
- Next step: execute CLI-only build and terminal checks on actual Ubuntu/Windows hosts; complete remaining specification semantics with separate observed RED/GREEN work units. The documentation/push follow-up is now user-authorized as scoped above; further remote operations require separate authorization.

## Documentation closure before authorized push
- [x] Updated native runtime lead with current host matrix, CLI-only shell/PowerShell quick path, beginner-guide link and independent final verification. Preserved behavioral RED/GREEN history and known small-input mismatches.
- [x] Reconciled historical pending commit/count statements with actual committed runtime work units; original broader compatibility tasks stay unchecked.
- Documentation-only closure: structural readback, local link/anchor validation and `git diff --check`; no new behavior, so no invented RED or unnecessary functional rerun. Existing root/Swift READMEs and beginner guide already describe implemented adapters and unverified hosts consistently.
- Delivery: documentation commit and push outcome remain parent-owned and pending here; no claim of successful CI or merge.

## Master integration and Windows compilation repair
- User authorized integrating the pending branch into master first, then fixing Windows compilation. Parent fast-forwarded local master to `2353048`; remote publication is not part of this bounded repair.
- [ ] W01: Repair implemented and macOS checks passed; Windows native compilation/GREEN remains pending. Replace the unavailable WinSDK `BOOL` callback spelling with `WindowsBool`, add a Windows-only native adapter compilation regression, and run the CLI build and focused suites.
- Strict TDD remains enabled. RED evidence is the reported Windows CI compiler error at NativeTerminal.swift:66; a fresh Windows RED/GREEN cannot be observed on this macOS host. Do not represent macOS checks as Windows verification.
- Rollback boundary: the callback type spelling and the Windows-only adapter regression; existing terminal behavior remains unchanged.
- Primary type evidence: Swift's `stdlib/public/Windows/WinSDK.swift` defines `WindowsBool` for Windows `BOOL`, boolean literals, and intrinsic conversions to/from Swift Bool. Existing WinSDK predicates and true/false callback returns therefore remain unchanged. Source: https://github.com/swiftlang/swift/blob/main/stdlib/public/Windows/WinSDK.swift.
- Checks observed on macOS after the repair: `TTFX_CLI_ONLY=1 swift build --product ttfx` passed (2.46 s); `TTFX_CLI_ONLY=1 swift test --filter 'TerminalRuntimeTests|TerminalLayoutTests|NativeTerminalPolicyTests|CLIParsingTests|CLIRuntimeTests|ProcessRunnerTests|PackageGraphTests'` passed 34 tests across 7 suites (0.933 s); `git diff --check` passed. Initial sandbox invocation could not write Swift's Clang module cache; the approved escalated rerun passed.
- Windows-only regression is excluded on macOS, not falsely counted as a Windows pass. CI's existing Windows focused-suite step selects it on Windows. Runtime harness N/A: this repair changes a compile-time type spelling only, not terminal behavior. Commit identity and final integration remain parent-owned.
