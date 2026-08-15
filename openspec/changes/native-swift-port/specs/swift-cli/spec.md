# swift-cli Specification

## Purpose

Command line executable `ttfx` (or `ttfx-swift`) that provides identical user experience and output to the Rust binary on macOS Terminal, using TTFXANSI renderer.

## Requirements

### Requirement: CLI Parity

The CLI SHALL support the same flags, options, argument parsing (using swift-argument-parser), --random-effect, completions, and terminal options as the Rust ttfx.

#### Scenario: Output Compatibility

- GIVEN same command line invocation and input
- WHEN running the binary
- THEN TTFXANSI output (escape sequences) produces byte-identical terminal stream to Rust version where applicable
- AND exit codes, help text, error messages match

#### Scenario: TTFXANSI Renderer

- GIVEN sequence of Frames from an effect
- WHEN rendering with TTFXANSI
- THEN minimal diff-based ANSI escape sequences are emitted matching upstream behavior

### Requirement: macOS Integration

The binary SHALL be built via SPM as executable target, installable via `swift build --product ttfx`, with native performance on Apple Silicon.

#### Scenario: Shell Completions

- GIVEN shell completion generation
- WHEN installed
- THEN provides completions for all options and effect names matching Rust

## Coverage
- Happy paths: common effect invocations, random mode
- Edge cases: invalid args, large canvases, completion signals
- Error states: proper error handling and messages
