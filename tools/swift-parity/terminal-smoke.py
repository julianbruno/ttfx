#!/usr/bin/env python3
"""Local POSIX terminal lifecycle smoke (not Windows/Linux certification)."""
import os
import pathlib
import pty
import select
import signal
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
SWIFT = ROOT / '.build/debug/ttfx'
RUST = ROOT / 'target/release/ttfx'
SHOW = b'\x1b[?25h'


def collect(fd, process, timeout=5):
    output = b''
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            output += data
        elif process.poll() is not None:
            break
    process.wait(timeout=2)
    return output


with tempfile.TemporaryDirectory() as directory:
    input_file = pathlib.Path(directory) / 'input.txt'
    input_file.write_text('TTFX\nRust + Swift\nVisual comparison')
    args = ['--input-file', str(input_file), '--seed', '42', '--frame-rate', '0', '--virtual-clock', '--canvas-width', '24', '--canvas-height', '8', 'print']
    swift = subprocess.run([SWIFT, *args], capture_output=True, check=True)
    rust = subprocess.run([RUST, *args], capture_output=True, check=True)
    assert swift.stdout == rust.stdout, (len(swift.stdout), len(rust.stdout))
    print('redirected complete print transcript: exact Rust/Swift bytes')
    start = time.monotonic()
    paced = subprocess.run([SWIFT, '--input-file', str(input_file), '--seed', '42', '--frame-rate', '10', 'print'], capture_output=True, check=True)
    elapsed = time.monotonic() - start
    assert 0.2 < elapsed < 15, elapsed
    print(f'real pacing: {elapsed:.3f} s (non-brittle bounds)')
    for sig in [signal.SIGINT, signal.SIGTERM]:
        master, slave = pty.openpty()
        process = subprocess.Popen([SWIFT, '--input-file', str(input_file), '--seed', '42', '--frame-rate', '1', 'print'], stdout=slave, stderr=subprocess.PIPE)
        os.close(slave)
        time.sleep(0.15)
        process.send_signal(sig)
        output = collect(master, process)
        os.close(master)
        assert SHOW in output, (sig, output)
        expected = 1 if sig == signal.SIGINT else -signal.SIGTERM
        assert process.returncode == expected, (sig, process.returncode)
        assert not process.stderr.read(), sig
        print(f'{sig.name}: cursor restored, status {expected}, quiet stderr')
    process = subprocess.Popen([SWIFT, '--input-file', str(input_file), '--seed', '42', '--frame-rate', '0', 'print'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    process.stdout.close()
    process.wait(timeout=5)
    assert not process.stderr.read()
    print(f'broken pipe: quiet exit {process.returncode}')
