# Native Swift terminal runtime

The Swift CLI now prepares a canvas, repaints in place, and restores the cursor on completion. It deliberately emits the same ANSI lifecycle when stdout is redirected, rather than silently switching to an ANSI-free format.

## Host status and quick path

| Host | Development state | Observed verification |
|---|---|---|
| macOS arm64 | CLI-only graph, POSIX terminal adapter and runtime implemented | Local builds, focused tests, Rust oracle checks and eight terminal smoke scenarios passed. |
| Ubuntu/Linux | CLI-only graph and POSIX adapter implemented | Native compilation and terminal behavior not yet verified. |
| Windows | CLI-only graph and conditional WinSDK adapter implemented | Native compilation, console restoration, Unicode, cancellation and resize not yet verified. |

For installation and first-time setup, use the [beginner platform guide](../getting-started-platforms.md). Requires Swift 6.2 or newer. Run from the repository root:

```sh
# macOS / Ubuntu
export TTFX_CLI_ONLY=1
swift build --product ttfx
printf 'Hello Swift' | swift run --skip-build ttfx --seed 42 --frame-rate 25 print
```

```powershell
# Native Windows PowerShell: commands to try, not a verified host result
$env:TTFX_CLI_ONLY = '1'
swift build --product ttfx
"Hello Swift" | swift run --skip-build ttfx --seed 42 --frame-rate 25 print
```

Before building Apple graphical products, unset `TTFX_CLI_ONLY` (or set it to `0`). Rust/WSL remain the guide's beginner reference paths for Ubuntu/Windows until native Swift host proof is available.

`--frame-rate 0` and `--virtual-clock` skip real pacing. Normal pacing waits the remainder of one frame interval, including before the first frame; it does not try to catch up after a slow frame. `--reuse-canvas`, `--no-eol`, and `--no-restore-cursor` affect canvas preparation and teardown.

## POSIX lifecycle

On macOS/Linux the native writer retries partial writes and EINTR, suppresses SIGPIPE, and stops quietly on a broken pipe. SIGINT requests cancellation and cursor cleanup with exit status 1. On terminal stdout, SIGTERM requests cleanup and then restores its default disposition and re-raises the signal. Handlers only store a small signal flag; rendering and allocation remain outside the handler. Previous signal dispositions are restored when the synchronous driver exits.

## Verification and limits

Observed independently on **macOS arm64, 2026-09-17**, after the runtime implementation:

| Check | Observed result |
|---|---|
| Graph/runtime/layout/policy | Final spot check: 18 functions in four suites passed, zero skips (1.093 s), including the Windows-style `Path` lookup regression. |
| Parser/parity/random/portable runner | 19 functions passed (25.753 s). Random checks include all 37 singleton candidates and four seeded multi-candidate cases; capped checks are not full sequence certification. |
| Complete effect parity and CLI runtime | 117/117 default/timed parameterized cases plus two CLI runtime functions passed, zero skips (74.436 s). |
| Native terminal smoke | Eight scenarios passed: exact recorded Rust/Swift Print transcript, real 10 FPS pacing (4.597 s), SIGINT/SIGTERM cleanup/status, quiet broken pipe, settled PTY resize, redirected SIGWINCH and interactive stdin. |
| Builds | CLI-only `ttfx` and normal `TTFXComparisonApp` builds passed. |

Behavior changes followed observed **RED → GREEN → REFACTOR**. The [work ledger](../../odd/tasks/cross-platform-cli.md) preserves exact failing assertions, commands, work-unit commits (`0741766`, `20ced14`, `5b5dad8`, `6248009`) and final evidence (`ebbcf3e`). Initial lifecycle RED had two failed assertions; cancellation-during-pacing emitted 13 bytes instead of none. Layout, RNG/clock and mixed-case executable lookup regressions were also observed before their fixes. Cache/linker/scratch-lock failures are not behavioral RED.

An earlier combined oracle run lost its `expand` subprocess with status 9. Isolated reruns and the subsequent independent required suite passed; that history remains recorded, not erased.

**Not certified:** Ubuntu/Windows host behavior, all inputs/settings, comprehensive non-default sequences or full CLI compatibility. Known pre-existing small-input mismatches remain: `errorcorrect` produces zero Rust frames versus one Swift frame in a short-input case; tiny inferred 2×1 Print differs in glyph/color despite matching frame counts. The recorded 24×8 Print transcript matches exactly.

T01 (CLI graph) and T05 (runtime) are locally complete; other specification tasks remain partial. See [remaining compatibility work](#dimensions-input-and-settled-resize) and the work ledger. No Linux/Windows test outcome is inferred from macOS PASS.

Rollback boundary: terminal/runtime adapters, CLI integration, related layout/RNG/clock changes, regression tests/smoke and their documentation together; keep the matching work-unit boundaries in the ledger. Hidden parity export and graphical products are preserved by the implementation.

## Dimensions, input, and settled resize

Dimensions resolve each axis independently: integer `COLUMNS`/`LINES`, native viewport query, then 80×24. Positive canvas dimensions are explicit, zero uses the viewport, and -1 uses input dimensions capped by the viewport unless `--ignore-terminal-dimensions` is set. CLI input width is Unicode-scalar based. Tabs expand to the configured fixed width. Input is strict UTF-8; interactive stdin does not wait for EOF. Empty/whitespace-only normal input exits quietly.

Text supports wrapping and canvas/text anchors. Canvas projection clips cells to the viewport. On terminal stdout only, viewport changes wait a 50 ms quiet window; a changed layout clears and rebuilds the previous canvas area. Ignored dimensions, unchanged layouts, and redirected stdout do not restart. The rebuilt effect consumes the **current RNG stream**, including initialization and tick draws—not a fresh stream with the original seed.

The opt-in CLI environment preserves default independent RNG/value semantics and virtual effect timing for galleries and parity captures. Normal CLI Matrix/Thunderstorm use monotonic real time; `--virtual-clock` retains tick-based timing. `--no-color` and `--xterm-colors` now apply to emitted frame colors, including actual cell background colors and explicit black foreground.

**Remaining compatibility work:** existing input ANSI colors in `always`/`dynamic` modes, terminal-background color blending, comprehensive invalid-input/diagnostic/hidden-mode semantics, and the full non-default effect corpus. Supported SGR input is currently stripped; this is not full input-ANSI parity.

## Native Windows adapter: implemented, not host-verified

The conditional WinSDK adapter distinguishes console handles using `GetConsoleMode`, preserves the output mode, enables processed/virtual-terminal output, and restores the original mode. Console output uses Unicode `WriteConsoleW`; redirected output uses UTF-8 `WriteFile` with explicit partial-write loops, without text-mode newline translation. Viewport size comes from `GetConsoleScreenBufferInfo.srWindow`, polled without consuming stdin events. Ctrl-C/Break use a preallocated atomic cancellation flag; normal driver teardown unregisters the handler. No handwritten C/Rust helper is used.

Close/logoff/shutdown keep default OS termination. Cursor cleanup is **not guaranteed** for those events; Microsoft documents that console functions may not work reliably then. Native Windows compilation, console mode restoration, cancellation, resize and Unicode behavior remain **unverified** until a Windows host runs them.

Primary references: [WriteConsole](https://learn.microsoft.com/en-us/windows/console/writeconsole), [SetConsoleMode](https://learn.microsoft.com/en-us/windows/console/setconsolemode), [SetConsoleCtrlHandler](https://learn.microsoft.com/en-us/windows/console/setconsolectrlhandler), [GetConsoleScreenBufferInfo](https://learn.microsoft.com/en-us/windows/console/getconsolescreenbufferinfo), and the [Swift WinSDK BOOL overlay](https://github.com/swiftlang/swift/blob/main/stdlib/public/Windows/WinSDK.swift).

## Three-platform CI definition

`.github/workflows/swift-cli.yml` defines CLI-only build, portable policy/parser/runtime tests, and help checks on macOS, Ubuntu and Windows. Windows uses the [Windows Swift setup action](https://github.com/compnerd/gha-setup-swift); macOS/Ubuntu reuse [setup-swift v2](https://github.com/swift-actions/setup-swift/tree/v2). The workflow is a definition, **not evidence of successful CI**. CI results are not yet confirmed; workflow presence does not prove host support.
