# parity-harness Specification

## Purpose

Automated test suite that treats the existing Rust `ttfx` binary as oracle to validate Swift implementation produces identical frames and behavior.

## Requirements

### Requirement: Fixture-Driven Validation

The harness SHALL generate or use pre-generated fixtures by running the pinned Rust binary across a comprehensive matrix, then compare Swift outputs byte-for-byte.

#### Scenario: Fixture Generation

- GIVEN pinned Rust commit and `tools/gen_fixtures.sh`
- WHEN executed
- THEN produces MANIFEST + Fixtures/ with frame dumps (header + per-cell data) for matrix of effects, sizes, seeds, configs
- AND fixtures are regenerable and tied to commit hash

#### Scenario: Test Execution

- GIVEN Swift effect instance configured identically to Rust invocation
- WHEN parity test runs full tick sequence
- THEN every serialized frame matches fixture exactly
- AND first mismatch reports exact tick, cell position, and values for debugging

### Requirement: DoD Enforcement

An effect SHALL only be considered complete when parity tests pass for full matrix, unit tests pass, and performance budgets are met.

#### Scenario: Wave Gates

- GIVEN completion of a wave's effects
- WHEN gate runs
- THEN all parity, perf, and unit tests pass for that wave's scope before advancing

## Coverage
- All 37 effects across representative matrix
- Regression detection for any divergence in math, RNG, logic, or ordering
