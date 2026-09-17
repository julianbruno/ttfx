# Native cross-platform Swift CLI with Rust parity

Build a native Swift command-line executable for Windows, macOS, and Linux that reproduces the existing Rust `ttfx` CLI and effect behavior, without graphical frameworks or a Rust runtime dependency. This specification is a standalone handoff for an agent with no prior conversation context.

**Status:** specification only, recorded 2026-09-17. The current request authorizes this Markdown document, not implementation, package changes, builds, commits, or remote operations. A future agent must obtain explicit implementation authorization and follow the current repository `AGENTS.md` and runtime permissions before changing source code.

## Quick path for a fresh agent

1. Read repository instructions, this document, and the source map below. Verify the current checkout rather than treating this snapshot as permanent truth.
2. Inventory the Rust CLI contract, effect registry, terminal behavior, and existing Swift gaps. Record the exact Rust reference revision used for comparisons.
3. After implementation authorization, establish a CLI-only Swift build graph, portable terminal boundaries, and regression tests before changing behavior.
4. Prove CLI parity and effect parity separately on the agreed supported platform matrix. Report unavailable or failing checks; never infer cross-platform support from a macOS build.

## Scope and constraints

| Area | Required outcome |
| --- | --- |
| Language | Application, engine, and effect implementation in Swift. |
| Platforms | Native Windows, macOS, and Linux binaries from one maintained implementation. Record actual tested OS versions, architectures, Swift toolchains, and terminal hosts. |
| Dependencies | Swift standard library, portable Foundation APIs, and Swift ArgumentParser. Verify compatible dependency/toolchain versions on all three systems before adopting them. Additional libraries require a documented portability need and tradeoffs. |
| Exclusions | No SwiftUI, AppKit, UIKit, Metal, video capture, GUI target, or Apple-only framework in the CLI dependency closure or CLI test graph. |
| OS interaction | Swift interop with operating-system APIs is allowed: POSIX on macOS/Linux and Windows console APIs on Windows. No handwritten C/Rust runtime or external helper replacing CLI behavior. |
| Reuse | Reuse `TTFXCore` and `TTFXEffects` where portable. Separate the CLI package/build graph from graphical products; choose the least disruptive package arrangement without duplicating the engine by default. |
| Independence | No launching, linking, or embedding the Rust executable to generate runtime output. Rust is a test oracle only. |
| Architecture | Small boundaries for parsing, input/layout, deterministic engine execution, terminal output, clock, and OS lifecycle. No fixed class count and no requirement for a new class per effect. Prefer appropriate Swift value types and protocols over inheritance for its own sake. |

Existing graphical products must remain usable. Their redesign is out of scope. Performance benchmarking is useful evidence but does not substitute for correctness or impose an unrequested numeric performance target.

## Verified starting point

These are source-inspection findings, not a successful build or platform certification:

- Root `Package.swift` declares Swift tools version 6.2, macOS 14/iOS 17 platform minimums, and ArgumentParser from 1.3.0. It mixes CLI, graphical, comparison, and capture products/tests.
- `TTFXCLI` depends directly on `TTFXCore`, `TTFXEffects`, and ArgumentParser; its source imports Foundation, not SwiftUI. The CLI already being nongraphical does **not** establish Windows/Linux portability.
- `runTerminalStream` writes successive frame bytes and optional newlines. It does not implement Rust's terminal preparation, in-place repaint lifecycle, or frame-rate enforcement in that loop.
- Normal `--random-effect` currently prints a pending-renderer message. Its parity/helper paths select the first candidate rather than the Rust seeded random choice.
- Swift CLI configuration uses `seed ?? 0`; Rust uses entropy when no explicit seed is provided.
- Swift input decoding uses replacement decoding rather than rejecting invalid UTF-8, and reads stdin to EOF without the Rust interactive-stdin check.
- Canvas dimensions in the inspected Swift CLI are inferred from text unless positive dimensions are supplied. Declared layout, color, cursor, and clock options are not evidence that their Rust semantics are implemented.
- The CLI's `terminalBytes` path emits foreground truecolor rather than routing all behavior through the separate `TTFXANSIRenderer`; inspect background colors, explicit black, xterm conversion, and no-color behavior.
- Existing Swift CLI tests and parity helpers are available, but were not executed for this document. No assertion is made that all existing effects match Rust.

## CLI contract

The authoritative reference is the selected Rust checkout's `src/cli.rs`, `src/main.rs`, registered effect configuration, and observed tests. Inventory every flag, alias, validation rule, default, ordering rule, and stream/exit behavior before implementation. Do not silently redefine Rust behavior to fit ArgumentParser defaults.

### Public options

Preserve effect names and per-effect flags, global help and effect help, `--version`/`-v`, `--input-file`/`-i`, `--seed`, `--print-completion`, `--random-effect`/`-R`, `--include-effects`, and `--exclude-effects`. Completion must support Rust's bash and zsh modes; a Windows executable does not imply an additional PowerShell requirement.

| Terminal option | Rust default in inspected checkout |
| --- | --- |
| `--tab-width` | 4 |
| `--xterm-colors`, `--no-color` | false |
| `--terminal-background-color` | `#000000` |
| `--existing-color-handling` | ignore |
| `--wrap-text` | false |
| `--frame-rate` | 60; zero disables frame-rate enforcement |
| `--canvas-width`, `--canvas-height` | -1; preserve distinct -1, zero, and positive semantics from Rust |
| `--anchor-canvas`, `--anchor-text` | sw |
| `--ignore-terminal-dimensions`, `--reuse-canvas` | false |
| `--no-eol`, `--no-restore-cursor` | false |

Preserve accepted color formats, anchor values, numeric bounds, invalid argument behavior, missing-effect behavior, and filter conflicts. Match semantic help content and option coverage; exact parser presentation or implementation-identifying version text may differ only when explicitly documented and approved. Runtime diagnostics, output channel, and exit status remain part of parity, including surprising Rust choices such as input-file errors on stdout.

### Input and layout

- File input takes precedence over piped stdin. Interactive stdin must not unexpectedly block waiting for EOF. Help, version, and completion must not require animation input.
- Reject invalid UTF-8; match empty/whitespace-input outcomes. Preserve Unicode scalar and width/layout behavior actually implemented by Rust, rather than assuming Swift grapheme counts are equivalent.
- Match tab expansion, newline handling, supported/unsupported ANSI input sequences, existing colors, wrapping, anchors, clipping, background handling, and canvas/input coordinate mapping.
- Match terminal dimension precedence: `COLUMNS`/`LINES` environment overrides, native console query, and Rust fallback of 80 by 24. Cover partial overrides and malformed values.

### Determinism and random selection

- Omitted seed obtains native entropy, not a constant seed. Explicit seeds produce deterministic output across supported platforms.
- Port the reference RNG algorithm, integer behavior, choice/shuffle semantics, registry ordering, and consumption sequence. The same seed alone is insufficient if RNG calls differ.
- Random selection uses the filtered Rust candidate ordering and reference RNG, runs the chosen effect with default effect configuration, and matches handling of ignored per-effect arguments and empty candidate sets.
- Provide injectable real and virtual clocks. Virtual-clock behavior must match Rust for clock-dependent effects; timing jitter must not become an excuse for frame differences in deterministic tests.

### Hidden compatibility modes

Preserve `--m0-dump`, `--parity-dump`, `--max-frames`, and `--virtual-clock` according to reference behavior, not merely similarly named Swift helpers. Match M0 output, length-prefixed frame byte counts, delimiters, frame-count diagnostics, termination, and flag interactions. Character counts are not UTF-8 byte lengths. Inspect boundary values such as a zero frame limit rather than guessing their meaning from help text.

## Terminal and platform behavior

Keep effect algorithms independent of OS handles. A terminal boundary must provide capability detection, dimensions, byte output/flush, cursor lifecycle, cancellation, and resize notifications. Use small platform adapters, not one supposedly portable Foundation call assumed to cover every console feature.

| Situation | Required behavior |
| --- | --- |
| Interactive animation | Match Rust canvas preparation, cursor hide/save/restore, in-place frame repaint, flushing, final newline, reuse-canvas, and no-restore/no-eol options. Restore terminal state on normal completion and applicable failures. |
| Pacing | Match real frame-rate enforcement and zero-rate behavior. Test with a fake clock; separately smoke-test real pacing without a brittle exact wall-time assertion. |
| Redirected stdout | Match Rust's actual emitted bytes and teardown rules, rather than inventing an ANSI-free mode. Distinguish pipe/file output from interactive handling. |
| Broken pipe/write failure | Do not crash noisily or continue producing frames indefinitely. Match the reference behavior and platform-equivalent exit outcome. |
| POSIX lifecycle | Match Ctrl-C/SIGINT, terminal SIGTERM teardown/termination, and settled SIGWINCH resize behavior. Do not perform unsafe allocation or rendering inside signal handlers. |
| Windows lifecycle | Provide corresponding console cancellation, capability setup, and resize handling through supported Windows APIs. Explain unavoidable semantic differences where POSIX signals have no exact counterpart. |
| Resize | Clear/rebuild/redraw in place after a settled interactive resize, preserving the reference RNG continuation and resetting reuse-canvas for the rebuild. Redirected output must not restart/truncate animation because the foreground terminal resized. |

Test Windows virtual-terminal capability setup and original console-state restoration, Unicode output, redirected handles, paths, and line-ending behavior. Do not translate ANSI frame bytes into platform-specific newlines. Native event differences require explicit evidence and approved exceptions; they are not a blanket parity waiver.

## Effect parity is a separate obligation

Matching argument parsing or terminal lifecycle does not mean the animations match. Every effect registered in the reference Rust CLI must be implemented natively and compared, including default settings and representative non-default values for every supported configuration dimension.

For a fixed input, canvas, seed, settings, and virtual clock, compare the complete sequence of ANSI frames, frame ordering/count, visible coordinates, foreground/background colors, character transitions, RNG-dependent choices, and completion. Match the full animation, not only duration, final text, or selected sample frames. Truncated tests are diagnostic tools, not proof of full-run parity.

No fixture playback, precomputed animations, effect-name placeholders, generic fallback animation, or Rust delegation may satisfy this requirement. Fixtures may serve as independent regression evidence only. Report genuinely nonterminating or intentionally continuous effects with an explicit bounded contract derived from Rust, rather than claiming completed full-run proof.

## Verification and acceptance

Repository instructions and `openspec/config.yaml` currently declare strict TDD; the recorded Swift runner is `swift test` and Rust runner is `cargo test`. This document does not initialize or select SDD. The implementation agent must reverify current configuration, package-specific runner applicability, and tool availability before running tests. With effective TDD enabled, record observed RED, implement GREEN, then REFACTOR; do not invent evidence.

| Proof layer | Minimum evidence |
| --- | --- |
| Build independence | CLI-only build and test graph on Windows, macOS, and Linux; no graphical target compilation/resources/framework dependency. Record toolchain and dependency versions. |
| Unit tests | Parser/validation, strict input decoding, dimensions/layout, ANSI serialization, seed/RNG, clock, lifecycle state transitions, and random filters. |
| CLI integration | Subprocess stdout/stderr/exit-status comparisons for successful and failing invocations, files/stdin, help/completion, hidden modes, and redirected/broken-pipe behavior. |
| Terminal integration | PTY-based macOS/Linux checks and suitable native Windows console tests for cursor cleanup, cancellation, resize, and repaint. State any unavailable host capability. |
| Effect comparisons | All registered Rust effects, full deterministic default runs and non-default coverage, multiple seeds, Unicode/ANSI/color/layout edge cases, and first differing frame diagnostics. |
| Platform automation | CI definitions covering all three OS families and agreed architectures, with build/test jobs and available parity suites. Creating CI configuration does not authorize remote execution or publishing. |

Acceptance checklist:

- [ ] The executable runs without any GUI framework or Rust runtime dependency on all three tested platforms.
- [ ] The Rust option/effect inventory has no omitted feature or unimplemented placeholder.
- [ ] Input, output bytes, diagnostics, exit outcomes, determinism, and platform lifecycle behavior satisfy the contract above.
- [ ] CLI and effect parity are reported independently, with failures and approved exceptions itemized.
- [ ] Existing graphical consumers are not broken by portable package separation.
- [ ] Setup/build/test documentation names tested toolchains, OS versions, dependencies, and limitations.

Never report global parity when a platform or effect is untested. A delivery report must distinguish passed, failed, skipped, blocked, and pending checks and identify the Rust reference revision.

## Source map

Paths below are repository-relative so this document survives checkout relocation. The authoring checkout was `/Users/julian/miscodigos/ttfx`; resolve these paths against the receiving agent's repository root.

| Path | Purpose |
| --- | --- |
| `Package.swift` | Current mixed Swift product/target graph and dependency declarations. |
| `Sources/ttfx-swift/CLI/TTFXCLI.swift` | Existing parser, input, stream renderer, completion, and hidden modes. |
| `Sources/ttfx-swift/Core/TTFXCore.swift` | Canvas/frame/input/configuration and effect contracts. |
| `Sources/ttfx-swift/Core/TTFXANSI.swift` | ANSI helpers and separate renderer. |
| `Sources/ttfx-swift/Core/EffectEngine.swift` | Existing engine integration. |
| `Sources/ttfx-swift/Effects/TTFXEffects.swift` | Swift effect registry; inspect its implementation and registered effect files. |
| `tests/ttfx-cliTests/` | Existing Swift parsing/runtime/parity tests. |
| `tests/ttfx-swiftTests/`, `tests/ttfx-effectsTests/` | Existing Swift core and effect tests. |
| `src/cli.rs`, `src/main.rs` | Rust CLI contract and execution lifecycle. |
| `src/engine/terminal.rs`, `src/engine/effect.rs` | Reference layout/output/pacing/resize and effect execution. |
| `src/lib.rs`, `src/utils/rng.rs`, `src/effects/` | Rust signal/platform behavior, RNG, and registered effect algorithms/configuration. |
| `tests/`, `script/`, `tools/`, `Cargo.toml` | Reference regression/parity tools and Rust dependencies; locate current applicable suites. |
| `openspec/config.yaml` | Existing testing configuration, not authorization to execute an SDD workflow. |

## Official references and unresolved evidence

[Swift platform support](https://www.swift.org/platform-support/) documents Windows, Linux, and macOS toolchain support. [Swift ArgumentParser](https://github.com/apple/swift-argument-parser) is the official parser project. These references establish tool availability, not that this repository or every Foundation API used by it is portable. Recheck release compatibility and platform API availability during implementation.

Still to verify after authorization: current Core/Effects dependency portability, reference suite coverage, target minimum OS/architecture matrix, Windows terminal-event mechanisms, package arrangement, and measured effect mismatches. Do not promise a fixed number of new classes or claim parity before those checks.
