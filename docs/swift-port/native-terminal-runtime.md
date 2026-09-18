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

Windows uses a temporary Foundation writer in this slice; its native console adapter is pending. Settled resize/rebuild, native dimension resolution, full input/layout/color compatibility, clock-dependent effect real-time injection, and cross-platform execution evidence remain pending. The lifecycle smoke does not certify every effect or Linux/Windows behavior.

Rollback boundary: terminal runtime/adapter files, normal stream integration, runtime tests/smoke, and this document together. Hidden parity export, engine algorithms, and GUI products remain unchanged.
