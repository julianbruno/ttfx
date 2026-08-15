# swift-ttfx-core Specification

## Purpose

Pure Swift animation engine using value types for zero-allocation hot path. Provides Canvas, Frame, Cell, Effect protocol, Xoshiro256++ RNG, easing, geometry, gradients. MUST produce byte-identical frames to Rust ttfx for same inputs, seed, config.

## Requirements

### Requirement: Zero-Allocation Engine

The system SHALL use only value types and pre-allocated ContiguousArrays so that `tick()` and frame mutation perform zero heap allocations in the steady state.

#### Scenario: Hot Path Performance

- GIVEN pre-allocated Frame (cols x rows) and effect state
- WHEN executing 500 ticks on 200x50 canvas with complex effect
- THEN zero allocations occur (verified by XCTMetric or allocation counter)
- AND median tick time < 1ms on M1 baseline

#### Scenario: Data Model

- GIVEN `struct Cell { UInt32 codepoint; RGBA fg, bg }` and `struct Frame { cols, rows; ContiguousArray<Cell> cells }`
- WHEN constructing and mutating
- THEN layout is 12 bytes per cell, flat memory, no ARC in hot path

### Requirement: Reproducible Parity Primitives

The system SHALL implement Xoshiro256PlusPlus, all easing functions, bezier geometry, gradient algorithms, and rounding behaviors to match Rust ttfx outputs exactly (including all documented quirks from plan.md and ordering-inventory.md).

#### Scenario: RNG Parity

- GIVEN identical seed
- WHEN generating random values during effect init and ticks
- THEN sequence is byte-identical to Rust oracle across all fixture cases

#### Scenario: Geometry and Easing

- GIVEN same input parameters as Rust test vectors
- WHEN computing paths, waypoints, easing values
- THEN outputs match golden fixtures from ttfx reference

### Requirement: Effect Protocol and Canvas

All 37 effects SHALL conform to `protocol Effect` with deterministic init from EffectConfig, CanvasSpec, seeded RNG, InputText and `mutating func tick(inout Frame) -> TickStatus`.

#### Scenario: Canvas Ingestion

- GIVEN text input, canvas dimensions, wrap rules matching upstream
- WHEN initializing effect
- THEN text is decomposed to scalars once, positions computed deterministically, state ready for ticking without per-tick String ops

## Scenarios Coverage
- Happy paths: covered for core primitives and typical effect execution
- Edge cases: empty text, 1-char, canvas smaller than text, completion states
- Error states: invalid configs rejected at init

**Size**: Core focused on WHAT (parity, zero-alloc, protocol). No implementation details.
