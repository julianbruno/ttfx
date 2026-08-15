#!/bin/sh
set -eu

# Fixture generation is deliberately delegated to ProcessRunner so oracle calls
# receive argument arrays, an environment allowlist, and a timeout.
swift test --filter "ParityHarnessTests"
