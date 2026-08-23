# Tasks: Native Swift Port of ttfx

**Total:** 27 — 11 complete, 16 pending.

## Review Workload Forecast

Changed lines: 8000-12000; approved single PR under `size:exception`.
Delivery strategy: exception-ok

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

### Work Units

| Unit | Deliverable | Focused | Runtime | Rollback |
|------|-------------|---------|---------|----------|
| 1 | Foundations/parity | `swift test` | `swift run ttfx --help` | Phase 0/1 |
| 2 | Substrate/composition | `swift test --filter AnimationCompositionTests` | seeded Rust trace | `Sources/ttfx-swift/Core/` |
| 3 | Effects | `swift test --filter EffectGroup1` | Rust/Swift fixture gate | Effects |
| 4 | CLI/TTFXANSI | `swift test --filter CLI` | stream parity vs Rust | `Sources/ttfx-swift/CLI/` |
| 5 | UI/release | `swift test --filter SwiftUI` | gallery/N/A optional | UI/CI/docs |

## Phase 0: Foundations

- [x] 0.1 Create `Package.swift` targets/dependency/platforms
- [x] 0.2 Implement core value types in `Sources/ttfx-swift/Core/`
- [x] 0.3 Port Xoshiro/easing/geometry/gradients in `Sources/ttfx-swift/Core/`
- [x] 0.4 Build parity harness/diagnostics in `tests/ttfx-swiftTests/Parity/`
- [x] 0.5 Add RED→GREEN core/RNG/canvas tests in `tests/ttfx-swiftTests/`

## Phase 1: Core

- [x] 1.1 Implement deterministic config/text init in `Sources/ttfx-swift/Core/`
- [x] 1.2 Implement tick state machine/completion in `Sources/ttfx-swift/Core/`
- [x] 1.3 Add <1ms/tick fixed-frame tests in `tests/ttfx-swiftTests/Core/`

## Phase 2

- [x] 2.0 RED: add `tests/ttfx-swiftTests/Core/AnimationSubstrateTests.swift` for stable character identity/grouping, visibility/layers, terminal collision resolution, path interpolation/holds, scene timing/loops, typed inline reentrant event order, completion, and fixed-capacity runtime orchestration. GREEN: implement ordered runtime in `Sources/ttfx-swift/Core/{Character,Motion,Animation,Events,TerminalModel,AnimationRuntime}.swift`; focused `swift test --filter AnimationSubstrateTests` fails then passes, followed by `swift test`.
- [x] 2.0a Strict RED→GREEN: `tests/ttfx-swiftTests/Core/AnimationCompositionTests.swift`: multi-segment/waypoint path chains; synchronized/resettable scenes; ordered groups/release-schedules/per-character-paths; gradients; typed chained actions without persistent closures; input-to-arena initialization/runtime-spawning; RuntimeEffect integration; deterministic RNG request-order. GREEN: `Sources/ttfx-swift/Core/MotionComposition.swift,Sources/ttfx-swift/Core/SceneComposition.swift,Sources/ttfx-swift/Core/CharacterScheduling.swift,Sources/ttfx-swift/Core/RuntimeActions.swift,Sources/ttfx-swift/Core/EffectRuntime.swift`; integrate existing substrate/engine only as required. Gates: focused `swift test --filter AnimationCompositionTests`, full `swift test`, seeded Rust trace fixture gate.
- [x] 2.1 Implement simple/particle: print_effect, slide, wipe, expand, rain, bubbles, fireworks, swarm in `Sources/ttfx-swift/Effects/`; dedicated tests: `tests/ttfx-swiftTests/Effects/`
- [ ] 2.2 Implement geometry-heavy effects: beams, rings, blackhole, laseretch, orbittingvolley, synthgrid; preserve bezier/order quirks
- [ ] 2.3 Implement remaining effects: burn, crumble, decrypt, errorcorrect, highlight, matrix, middleout, pour, scattered, smoke, thunderstorm, unstable, vhstape, waves, etc.
- [ ] 2.4 Add a RED parity test before each effect's GREEN implementation
- [ ] 2.5 Run the 37-effect parity matrix gate

## Phase 3

- [ ] 3.1 Implement `TTFXCLI` ArgumentParser for Rust flags/options, random effect, terminal options/colors, and completions
- [ ] 3.2 Implement exact-byte `TTFXANSI` rendering
- [ ] 3.3 Add CLI integration/Rust stream-parity tests
- [ ] 3.4 Update executable entrypoint/completions

## Phase 4

- [ ] 4.1 Implement SwiftUI views and Metal real-time renderer
- [ ] 4.2 Build interactive effects gallery/demo
- [ ] 4.3 Add renderer snapshot/performance tests

## Phase 5

- [ ] 5.1 Finalize `Package.swift`, dependencies, SPM docs
- [ ] 5.2 Add Swift CI workflow in `.github/workflows/`
- [ ] 5.3 Update `docs/swift-port/` fixtures/docs and extend `./bin/test`
- [ ] 5.4 Verify proposal criteria and update `README.md`
- [ ] 5.5 Run final full-matrix parity check

## Implementation Order

Order: 2.0/2.0a → effects → CLI/SwiftUI; enforce RED→GREEN/gates.
