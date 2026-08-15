# swift-effects-parity Specification

## Purpose

Complete implementation of all 37 ttfx effects in Swift that produce byte-identical frame sequences to the Rust reference binary.

## Requirements

### Requirement: Full Effect Coverage

The system SHALL implement all 37 effects listed in `ttfx --help` (exact list reconciled in Wave 0), each in its own file conforming to the Effect protocol from swift-ttfx-core.

#### Scenario: Parity Validation

- GIVEN fixture matrix (all effects × canvas sizes 80x24/200x50 × seeds 1/424242 × representative configs)
- WHEN running parity harness on Swift effect vs Rust oracle
- THEN every frame's serialized Cell data matches byte-for-byte
- AND completion status and total ticks match

#### Scenario: Incremental Waves

- GIVEN wave-based delivery (foundations, then groups of 5-12 effects)
- WHEN an effect is marked complete
- THEN its unit tests, parity tests, and perf budgets all pass before merging

### Requirement: Quirk Reproduction

Each effect implementation SHALL deliberately reproduce all documented upstream quirks (rounding, ordering, off-by-one behaviors, scene looping semantics) with explicit `// QUIRK(...)` comments referencing plan.md or ordering-inventory.md.

#### Scenario: Edge Case Handling

- GIVEN empty input, single character, canvas smaller than text, extreme seeds/configs
- WHEN ticking the effect
- THEN behavior matches Rust reference exactly (no creative improvements)

## Coverage
- Happy paths: standard text animations
- Edge cases: all matrix cases + unit test edges
- Error states: invalid effect config rejected early

**Note**: swiftui-renderer is optional and does not affect core parity.
