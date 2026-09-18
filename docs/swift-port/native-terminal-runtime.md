# Native Swift terminal runtime

The Swift CLI now prepares a canvas, repaints in place, and restores the cursor on completion. It deliberately emits the same ANSI lifecycle when stdout is redirected, rather than silently switching to an ANSI-free format.

```sh
TTFX_CLI_ONLY=1 swift build --product ttfx
printf 'Hello Swift' | .build/debug/ttfx --seed 42 --frame-rate 25 print
```

`--frame-rate 0` and `--virtual-clock` skip real pacing. Normal pacing waits the remainder of one frame interval, including before the first frame; it does not try to catch up after a slow frame. `--reuse-canvas`, `--no-eol`, and `--no-restore-cursor` affect canvas preparation and teardown.

## POSIX lifecycle

On macOS/Linux the native writer retries partial writes and EINTR, suppresses SIGPIPE, and stops quietly on a broken pipe. SIGINT requests cancellation and cursor cleanup with exit status 1. On terminal stdout, SIGTERM requests cleanup and then restores its default disposition and re-raises the signal. Handlers only store a small signal flag; rendering and allocation remain outside the handler. Previous signal dispositions are restored when the synchronous driver exits.

## Verification and limits

Observed on macOS arm64 only:

- `TTFX_CLI_ONLY=1 swift test --filter TerminalRuntimeTests`: original lifecycle RED (two failed assertions), then GREEN. Additional cancellation-during-pacing RED produced 13 output bytes instead of none, then GREEN after checking cancellation after the wait.
- `python3 tools/swift-parity/terminal-smoke.py`: exact full redirected Rust/Swift Print transcript for seed 42, 24×8 canvas, recorded comparison input; real pacing; PTY SIGINT/SIGTERM cleanup and status; quiet broken pipe.
- Tiny two-character input at inferred 2×1 canvas exposes an existing Print effect frame mismatch (color/glyph), independently of matching frame counts and terminal lifecycle. This is not fixed or certified by runtime checks.

The first slice left Windows, resize, dimensions and effect real-time injection pending; implementation progress is recorded below. Full input/layout/color compatibility and cross-platform execution evidence remain pending. The lifecycle smoke does not certify every effect or Linux/Windows behavior.

Rollback boundary: terminal runtime/adapter files, normal stream integration, runtime tests/smoke, and this document together. Hidden parity export, engine algorithms, and GUI products remain unchanged.

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

`.github/workflows/swift-cli.yml` defines CLI-only build, portable policy/parser/runtime tests, and help checks on macOS, Ubuntu and Windows. Windows uses the [Windows Swift setup action](https://github.com/compnerd/gha-setup-swift); macOS/Ubuntu reuse [setup-swift v2](https://github.com/swift-actions/setup-swift/tree/v2). The workflow is a definition, **not evidence of successful CI**. It has not been pushed or run remotely in this task.
