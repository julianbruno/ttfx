# Apply Progress: Native Swift Port

**Mode:** Strict TDD
**Delivery:** Single PR with maintainer-approved `size:exception`
**Completed work units:** `wave-0-foundations`, `phase-1-core-engine`, `phase-2-animation-substrate`, `phase-2-animation-composition`, `phase-2-dynamic-gradient-contract`, `phase-2-shared-runtime-execution`, `phase-2-shared-runtime-contract-gaps`, `phase-2-effect-oracle-boundary`, `phase-2-print-effect`, `phase-2-slide-effect`, `phase-2-wipe-effect`, `phase-2-expand-effect`, `phase-2-simple-effects-contract-gaps`
**Attempted work units:** `phase-2-simple-effects-documentary-gate` (QUIRK planning refs added; standalone hash receipt passed; full-suite and generator-check receipts recorded as failing after HEAD checkpoint)
**Status:** 12/27 tasks complete

## Completed Tasks

- [x] 0.1 Restore the runnable Swift package baseline with valid module, executable, and test boundaries.
- [x] 0.2 Add value-type core primitives: `Cell`, `Frame`, `Canvas`, `InputText`, `Effect`, and `TickStatus`.
- [x] 0.3 Add deterministic Xoshiro256++, Python-compatible math, easing, geometry, and gradient primitives.
- [x] 0.4 Add a safe fixture/parity harness with an injected argument-array process runner and mismatch diagnostics.
- [x] 0.5 Add parity-focused core, RNG, canvas, and first-cell-diagnostic tests.
- [x] 1.1 Add deterministic effect-engine initialization from configuration, canvas, input scalars, and seed.
- [x] 1.2 Add the ticking state machine with terminal completion behavior.
- [x] 1.3 Add deterministic fixed-frame performance and allocation-proxy evidence.
- [x] 2.0 Add the ordered minimum animation substrate prerequisite: stable character arena/grouping, renderer collisions, motion paths/holds, scenes, typed reentrant events, completion, seeded runtime state, and fixed-capacity rendering.
- [x] 2.0a Add shared motion, scene, scheduling, typed-action, input-arena, and `RuntimeEffect` composition prerequisites.
- [x] 2.1 Implement simple/particle: print_effect, slide, wipe, expand, rain, bubbles, fireworks, swarm in `Sources/ttfx-swift/Effects/`; dedicated tests: `tests/ttfx-swiftTests/Effects/`
- [x] 2.2 Implement geometry-heavy effects: beams, rings, blackhole, laseretch, orbittingvolley, synthgrid; preserve bezier/order quirks

## TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| 0.1 | `Core/PackageBaselineTests.swift` | Package integration | N/A — broken baseline was the required first RED | `swift test` exit 1: inaccessible ANSI dependency and empty target; then the new test preceded package/source edits | `swift test --filter PackageBaselineTests` exit 0; 1 test passed | Skipped — structural module-linkability contract | None needed; reran focused test after package boundary cleanup |
| 0.2 | `Core/CorePrimitivesTests.swift` | Unit | `swift test --filter CorePrimitivesTests` pre-edit: 3/3 passing after the package baseline | Test compile failed because `Cell`, `Frame`, `Canvas`, `EffectConfiguration`, `Effect`, and `TickStatus` did not exist | Same command exit 0; 3 tests passed | Cell/frame mutation, Unicode/bottom-up ingestion, and effect completion paths | None needed; value types remain direct and allocation-conscious |
| 0.3 | `Core/ParityPrimitivesTests.swift` | Unit | `swift test --filter CorePrimitivesTests` exit 0; 3 tests passed | Test compile failed because RNG, compatibility math, geometry, gradient, and easing APIs did not exist | `swift test --filter ParityPrimitivesTests` exit 0; 4 tests passed | Seed 42 words, seed 7 integer range, rounding/division/geometry, gradients, easing endpoints, insertion order | Corrected two initial expected literals from the pinned shim/Rust formula, then reran GREEN; no production refactor required |
| 0.4 | `Parity/ParityHarnessTests.swift` | Integration | N/A — new harness production file | Test compile failed because `ProcessRunner`, fixture generator, frame decoder, and errors did not exist | `swift test --filter ParityHarnessTests` exit 0; 4 tests passed | Literal metacharacter arguments; missing/non-executable/timeout/nonzero oracles; relative and absolute Git roots; truncated frames; generated fixture | None needed; process interface remains argument-array-only |
| 0.5 | `Parity/CoreParityScenariosTests.swift` | Unit/parity | `swift test --filter ParityHarnessTests` exit 0; 4 tests passed | Test compile failed because `FrameParity.firstCellMismatch` and `CellMismatch` did not exist | `swift test --filter CoreParityScenariosTests` exit 0; 3 tests passed | First tick/cell/word diagnostic; empty and undersized canvas input; invalid dimensions; second RNG seed | None needed; reran the full Swift suite |
| 1.1 | `Core/EffectInitializationTests.swift` | Unit | `swift test` exit 0; 15 tests passed before Phase 1 edits | Test compile failed because configuration text/seed and `EffectEngine` did not exist | `swift test --filter EffectInitializationTests` exit 0; 2 tests passed | Multi-line Unicode input and empty input initialization paths | None needed; immutable initialization state is already direct |
| 1.2 | `Core/EffectTickTests.swift` | Unit | `swift test --filter EffectInitializationTests` exit 0; 2 tests passed | Test compile failed because `EffectEngine.tick()` did not exist | `swift test --filter EffectTickTests` exit 0; 2 tests passed | Two-step running-to-complete transition and immediate completion no-op | None needed; completion guard is minimal |
| 1.3 | `Core/EffectPerformanceTests.swift` | Performance/unit | `swift test --filter EffectTickTests` exit 0; 2 tests passed | Test compile failed because fixed-frame capacity and bounded tick-run APIs did not exist | `swift test --filter EffectPerformanceTests` exit 0; 1 test passed | Five 100-tick samples on a 200x50 preallocated frame; median asserted below 1 ms | Replaced coordinate-by-coordinate mutation with direct mutable-frame storage access; reran the focused test |
| 2.0 | `Core/AnimationSubstrateTests.swift` | Unit/runtime | `swift test` exit 0; 20 tests passed before Phase 2 edits | `swift test --filter AnimationSubstrateTests` exit 1 because `TerminalModel`, `AnimationRuntime`, motion, scene, and event types did not exist | `swift test --filter AnimationSubstrateTests` exit 0; 7 tests passed | Stable IDs/groups, visibility/layers/collisions, path movement/hold/completion, finite/looping scenes, inline reentrant events, ordered render/capacity, and second-seed RNG scheduling | Consolidated mutually recursive value models into one substrate file; reran focused and full suites |
| 2.0a | `Core/AnimationCompositionTests.swift` | Unit/runtime trace | `swift test --filter AnimationCompositionTests` exit 0; 9 tests passed before dynamic-gradient edits | Initial RED failed because composition types and `RuntimeEffect` did not exist; corrective RED then failed because `CharacterSeed`, `CharacterGroupSequence`, `PathChainCursor`, and metric-based scene synchronization did not exist; dynamic-color RED failed because `GradientColorBehavior` and `SceneBuilder` behavior parameters did not exist | `swift test --filter AnimationCompositionTests` exit 0; 11 tests passed | Multi-segment/eased/held cursor, resettable chained control points, distinct step/progress/distance scenes, static and dynamic foreground/background/no-color gradients with coordinate mapping, seed/group/path assignment, build-once runtime effect, and exact Xoshiro draw values | Corrected the RED expectation to Rust terminal geometry (row distance counts double), replaced an ephemeral recursive action test with a typed chain drain, corrected same-tick chain activation, then extracted scoped gradient-color selection after dynamic interpolation triangulation |
| 2.0a runtime execution correction | `Core/RuntimeExecutionTests.swift` | Runtime integration | `swift test --filter AnimationSubstrateTests` exit 0; 7 tests passed, then `swift test --filter AnimationCompositionTests` exit 0; 11 tests passed | `swift test --filter RuntimeExecutionTests` exit 1 because composed path/scene installation, typed runtime actions, named random operations, release scheduling, and anchors did not exist | `swift test --filter RuntimeExecutionTests` exit 0; 5 tests passed | Composed chains across holds/easing/control points, distance scenes/reset/frame rendering, inline activated-path action dispatch, named integer/uniform/choice rejection draws, group releases, anchors/retirement, stable order, and `RuntimeEffect` ticks | Removed an unused stored path copy from the runtime cursor state after the full runtime assertions passed; reran the focused suite |
| 2.0a shared runtime contract gaps | `Core/RuntimeExecutionTests.swift` | Runtime integration | `swift test --filter RuntimeExecutionTests` exit 0; 5 tests passed; composition and substrate safety nets were 11/11 and 7/7 | RED compile failed because assigned-path installation and emitted-event draining did not exist; the subsequent synchronized-reset test failed because reset did not apply the initial frame | `swift test --filter RuntimeExecutionTests` exit 0; 10 tests passed | Finite/looped synchronized scene completion/reset, inline typed emit delivery to `RuntimeEffect`, assigned paths, active-anchor retirement/release pruning, effect completion, and canonical diagonal release order | Extracted shared scene-metric construction after all gap scenarios passed; reran the focused suite |

## Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused test command | `swift test` — exit 0; Swift Testing ran 15 tests, all passed. |
| Runtime/parity harness | `swift build --product ttfx && swift run ttfx --help` — exit 0; executable built and emitted help. `swift test --filter ParityHarnessTests` — exit 0; 4 tests exercised real `/usr/bin/printf`, `/usr/bin/false`, `/bin/sleep`, local `git`, safe argument handling, timeout, nonzero exit, and frame decoding. |
| Rollback boundary | Revert `Package.swift`, `Sources/ttfx-swift/{Core,Effects,CLI}/`, `Tests/ttfx-swiftTests/{Core,Parity}/`, `tools/swift-parity/`, this progress artifact, and the five Phase 0 checkboxes. Rust production code remains untouched. |

## Phase 1 Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused tests | `swift test --filter EffectInitializationTests` — exit 0, 2 tests passed; `swift test --filter EffectTickTests` — exit 0, 2 tests passed; `swift test --filter EffectPerformanceTests` — exit 0, 1 test passed. |
| Runtime harness | `swift test` — exit 0; 20 Swift Testing tests passed, including the 500 total ticks across five 200x50 fixed-frame samples. `swift build --product ttfx && swift run ttfx --help` — exit 0; package linked and executable emitted help. |
| Performance/allocation proxy | The Phase 1 performance test measures five independent 100-tick runs, asserts median per-tick time below 1 ms, verifies each run performs all 100 ticks on a 10,000-cell frame, and proves the `ContiguousArray` capacity is unchanged. It does **not** measure or claim zero heap allocations; XCTest allocation metrics are not available in this Swift Testing package target. |
| Rollback boundary | Revert `Sources/ttfx-swift/Core/EffectEngine.swift`, the Phase 1 additions in `Sources/ttfx-swift/Core/TTFXCore.swift`, `tests/ttfx-swiftTests/Core/{EffectInitializationTests,EffectTickTests,EffectPerformanceTests}.swift`, the three Phase 1 task checkboxes, and the Phase 1 portions of this artifact. |

## Phase 2.0 Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused test command | `swift test --filter AnimationSubstrateTests` — exit 0; 7 Swift Testing tests passed. |
| Full test command | `swift test` — exit 0; 27 Swift Testing tests passed. |
| Runtime harness | The seeded in-process tick/render scenario in `runtimeOrchestratesOrderedTicksRenderingCompletionAndFixedFrameCapacity` passed: ascending IDs `[0, 1]` updated motion before rendering, rendered crossing characters into a fixed-capacity two-cell frame, and completed after one tick. `runtimeRetainsSeededRNGStateForDeterministicEffectScheduling` passed with two equal seed-42 draws and a distinct seed-7 draw. |
| Capacity limitation | The runtime test proves `Frame.storageCapacity` remains unchanged. It does not measure or claim zero heap allocations because the Swift Testing target has no allocation metric. |
| Rollback boundary | Revert `Sources/ttfx-swift/Core/AnimationSubstrate.swift`, `tests/ttfx-swiftTests/Core/AnimationSubstrateTests.swift`, task checkbox 2.0, and this Phase 2.0 evidence. No effects, CLI, or Rust source changed. |

## Historical Phase 2.1 Discovery Blocker

- Rust mapping showed that all eight assigned effects require input-to-arena construction, ordered multi-segment/eased paths, path chains, scene gradients/synchronization, typed path/scene completion actions, and effect-owned scheduling state.
- This historical finding motivated the shared runtime correction recorded below. It was not safe to implement those contracts as effect-local substitutes.
- No task 2.1 source or test file was created in this discovery work; task 2.1 remains unchecked.

## Shared Runtime Prerequisites for Phase 2.1

The shared correction wires `ComposedPath`, `PathChainCursor`, terminal-aware `ScenePlayback`, `SceneBuilder` output, typed `RuntimeActions` including inline emitted values, named Rust-compatible random draws, releases, anchors, retirement, rendering, and `RuntimeEffect.tick` into active `AnimationRuntime` updates. `TTFXEffects` remains deliberately empty: this unit adds no named effect algorithm or fixture.

| Effect | Rust-faithful behavior mapped | Shared runtime seam now available |
|---|---|---|
| `print_effect` | Appends a typing-head anchor, types row groups at a configured rate, shifts completed rows, and uses dynamic foreground/background fade scenes. | Runtime anchors, typed actions, composed scenes, and per-tick rendering. |
| `slide` | Starts row/column/diagonal groups off canvas, releases each group with gap/merge/reverse rules, and activates input paths. | Release plans and composed path activation. |
| `wipe` | Uses `SequenceEaser` add/remove sets, resets removed scenes, and exposes only eased groups. | Scene reset/deactivation and stable runtime updates; effect must implement its own mapped easer policy. |
| `expand` | Starts every character at center, follows eased input paths, and synchronizes final gradients to path distance. | Distance metrics, composed paths, and scene playback. |
| `rain` | Draws per-character color, symbol, and speed in that order; releases row groups with further bounded random draws. | Named `choice`/`uniform`/bounded-integer operations and release execution. |
| `bubbles` | Adds anchor characters, moves circular groups, detects landing, then runs pop/path/scene chains. | Runtime anchors, retirement, multi-character updates, and typed chains. |
| `fireworks` | Creates seeded shell groups, random origins/explosion points/speeds, Bezier bloom paths, and jittered launches. | Named random operations, control-point paths, and release lifecycle. |
| `swarm` | Builds seeded swarm areas with a mutable shuffled-circle-cache quirk, chained paths, synchronized flashes, and probabilistic coordination. | Path chains, distance scenes, typed actions, and named random traces; effect owns its mapped cache quirk. |

No effect source or test was added, no task checkbox changed, and no required task 2.1 fixture gate was run. The next task 2.1 work unit must still create per-effect RED tests and prove its own Rust/Swift fixtures before checking that task.

## Task 2.1 Oracle Boundary Recovery

`tests/fixtures/effects/manifest.json` pins Rust revision `6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a` and eight deterministic 12×6, seed-42, length-prefixed UTF-8 terminal-frame traces. `tools/swift-parity/generate-effect-oracles.sh` regenerates them with fixed literal arguments and stdin only, using Rust `--parity-dump`; no user-provided effect/input crosses a shell interpolation boundary. `TTFXEffectsTests` depends only on `TTFXEffects`; `TTFXCore` is available transitively through that production target, preserving the test dependency direction.

The Core seam now includes exactly the required Rust effect easings (`outExpo`, `outCirc`, `inOutQuart`, `inOutExpo`, `outSine`, `inOutSine`), per-character optional preexisting foreground/background values, and named closed/half-open range, choice, and shuffle operations. Rejection draws preserve the operation name for each consumed Xoshiro word. No named Swift effect was implemented; task 2.1 remains unchecked until each effect has its own RED parity test and GREEN implementation.

## Effect Oracle Boundary Work Unit Evidence

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter EffectOracleFixtureTests` compiled the isolated effect target then failed because `print.frames` did not exist. `swift test --filter EffectOraclePrimitivesTests` failed to compile because the six easing cases, per-character colors, and named choice/range/shuffle APIs did not exist. |
| GREEN | The generator emitted 32 frames for `print`, `slide`, `wipe`, `rain`, `bubbles`, `fireworks`, and `swarm`, and 18 for `expand`. Focused fixture and primitive tests then passed. |
| Full suite | `swift test` — exit 0; 52 Swift Testing tests passed. `git diff --check` — exit 0. |
| Scope limitation | Raw frames prove the deterministic Rust terminal-render oracle and fixture schema only. They do not claim Swift parity for any named effect, zero allocations, or task 2.1 completion. |
| Rollback boundary | Revert `Package.swift`, `Sources/ttfx-swift/Core/{MotionComposition,AnimationSubstrate,RuntimeExecution}.swift`, `Tests/ttfx-effectsTests/`, `tests/ttfx-swiftTests/Core/EffectOraclePrimitivesTests.swift`, `tests/fixtures/effects/`, `tools/swift-parity/generate-effect-oracles.sh`, and this evidence. Keep task 2.1 unchecked. |

## Phase 2.0a Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused test command | `swift test --filter AnimationCompositionTests` — exit 0; 11 Swift Testing tests passed. |
| Full test command | `swift test` — exit 0; 38 Swift Testing tests passed. |
| Rust-derived trace | `typedActionsChainPathsInlineInTheRustFixtureOrder` compares `activatePath:p2`, `activatePath:p3`, `emit:settled` with `tests/fixtures/engine_traces.txt` lines 135–153. `runtimeRecordsExactRustXoshiroDrawTraceInRequestOrder` compares seed-42 Xoshiro request values `15021278609987233951`, `5881210131331364753` and request labels `color`, `symbol` with the pinned parity shim sequence. |
| Capacity limitation | Runtime integration retains fixed frame capacity but does not claim heap-allocation measurement because Swift Testing exposes no allocation metric. |
| Rollback boundary | Revert `Sources/ttfx-swift/Core/{MotionComposition,SceneComposition,CharacterScheduling,RuntimeActions,EffectRuntime}.swift`, Phase 2.0a additions in `AnimationSubstrate.swift`, `tests/ttfx-swiftTests/Core/AnimationCompositionTests.swift`, task checkbox 2.0a, and this evidence. The dynamic-gradient correction is isolated to `SceneComposition.swift` and its direct tests. No effects, CLI, or Rust source changed. |

## Shared Runtime Execution Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused test command | `swift test --filter RuntimeExecutionTests` — exit 0; 5 Swift Testing tests passed. |
| Seeded trace gate | `swift test --filter runtimeRecordsExactRustXoshiroDrawTraceInRequestOrder` — exit 0; 1 Swift Testing test passed. The runtime tests additionally pin rejected-draw values for seed 42 named integer/choice operations. |
| Full test command | `swift test` — exit 0; 43 Swift Testing tests passed. |
| Runtime scenario | `runtimeExecutesComposedChainsAndSynchronizedScenes` executes a composed hold/control-point chain and distance scene into a `Frame`; `runtimeSchedulesReleasesRetiresAnchorsAndDrivesComposedEffects` proves `RuntimeEffect.tick` builds once, advances a composed path, renders it, releases a hidden character, and retires an anchor. |
| Rollback boundary | Revert `Sources/ttfx-swift/Core/RuntimeExecution.swift`, the runtime-execution additions in `AnimationSubstrate.swift`, `RuntimeActions.swift`, and `CharacterScheduling.swift`, `tests/ttfx-swiftTests/Core/RuntimeExecutionTests.swift`, and this work-unit evidence. Keep task 2.1 unchecked. No effect, CLI, or Rust source changed. |

## Shared Runtime Contract Recovery Evidence

| Evidence | Exact result |
|---|---|
| Focused tests | `swift test --filter RuntimeExecutionTests` — exit 0; 10 Swift Testing tests passed. `swift test --filter AnimationCompositionTests` — exit 0; 11 passed. `swift test --filter AnimationSubstrateTests` — exit 0; 7 passed. |
| Seeded trace | `swift test --filter runtimeRecordsExactRustXoshiroDrawTraceInRequestOrder` — exit 0; 1 passed. Named integer/choice rejection draws remain pinned in `RuntimeExecutionTests`. |
| Full suite | `swift test` — exit 0; 48 Swift Testing tests passed. |
| Runtime scenarios | Finite scenes render their terminal frame, dispatch `.sceneComplete`, then deactivate; looped scenes remain active; reset immediately restores the synchronized scene's initial visual. Typed `.emit` values drain to `RuntimeEffect.receiveRuntimeEvent` in the same tick. Retired active anchors are skipped during release and excluded from active updates/rendering while their stable IDs remain allocated. |
| Rollback boundary | Revert the contract-recovery changes in `Sources/ttfx-swift/Core/{AnimationSubstrate,SceneComposition,EffectRuntime,RuntimeExecution}.swift`, `tests/ttfx-swiftTests/Core/RuntimeExecutionTests.swift`, `openspec/config.yaml`, and this recovery evidence. Task 2.1 remains unchecked. |

## Testing Metadata Reconciliation

`openspec/config.yaml` now records the observed runnable Swift Testing package: `swift test` is available for unit and runtime-integration work, and `rules.apply.test_command` is `swift test`. Execution mode, delivery strategy, strict TDD, and the no-RDD apply rule are unchanged.

## Phase 2.0a Contract Recovery Evidence

| Validator gap | RED→GREEN proof |
|---|---|
| Mutable architecture progress | Removed stale completion/test counts from `design.md` technical approach; the design remains below 800 words. |
| Seeds and groups | `characterSeedsAndGroupSequencePreserveStableIdentityAndDistinctPaths` proves append-only IDs, row grouping, and seeded spawn metadata. |
| Path chain | `pathChainCursorUsesEveryPathResetsAndHonorsControlPoints` proves `PathChain` is executed, advances into the second path on completion, resets, and samples a Bezier control point. |
| Scene synchronization | `sceneSynchronizationModesRemainDistinctAndGradientVariantsPreserveColors` proves `.step`, `.progress`, and `.distance` select distinct frames. |
| Gradients | The same test proves foreground/background RGB words, nil-gradient clear frames, and horizontal coordinate-color ordering. |
| Per-character paths | `CharacterGroupSequence.assign(paths:)` maps each stable character ID to a distinct `ComposedPath`; the test rejects equivalent first/second assignments. |
| Exact RNG trace | `runtimeRecordsExactRustXoshiroDrawTraceInRequestOrder` asserts the first two seed-42 Rust Xoshiro outputs and labels in draw order. |
| Dynamic preexisting colors | `dynamicGradientSidesBridgeFromEachPreexistingColor` proves dynamic foreground and background bridges use each supplied preexisting color, preserve static/nil behavior, and leave coordinate-color mapping unchanged. `dynamicGradientInterpolationUsesTheSourceLengthForEachCell` proves a longer bridge preserves per-frame duration cycling and interpolates to a distinct preexisting foreground. |
| Runtime execution | `RuntimeExecutionTests` proves the previously standalone composed path, scene, typed-action, named-RNG, anchor, and release contracts execute through `AnimationRuntime` and `RuntimeEffect` ticks. |
| Runtime contract gaps | The recovery tests prove terminal scene completion/actions, emitted-event delivery, assigned-path execution, active-anchor pruning, finite `RuntimeEffect` completion, synchronized reset output, and diagonal releases. |

## Deviations

- The executable product is named `ttfx`, following `design.md` and `swift-cli/spec.md`; the library product remains `ttfx-swift`. This resolves the stale task wording while retaining the documented SPM command `swift build --product ttfx`.
- The Phase 0 fixture script validates the local harness. Full persisted effect-matrix fixtures remain intentionally deferred until effects exist in Phase 2; the generator API already pins a local Git revision, runs an explicit oracle argument array, and decodes its frame dump.
- Task 1.3's XCTMetric/zero-allocation wording is not directly supportable by the Swift Testing target. The implemented deterministic proxy preserves the performance intent but only proves sub-millisecond median work and fixed frame storage capacity; it intentionally makes no heap-allocation claim.
- **Substrate file organization:** task 2.0 names six conceptual models. They are consolidated in `Core/AnimationSubstrate.swift` because their value types are mutually recursive (`CharacterState` owns motion, animation, and events; `AnimationRuntime` coordinates all of them). This keeps the ordered contract in one auditable file without introducing circular module seams; each required model remains a distinct public type.
- **Phase 2.1 boundary:** the shared runtime correction now executes the composition seams required before effect implementation. Task 2.1 remains unimplemented and still requires per-effect Rust/Swift fixture evidence; no effect-local substitute was introduced.
- **Phase 2.0a trace boundary:** the composition fixture proves Rust engine ordering for the shared `p1 → p2 → p3` action chain, not byte parity for any effect. Effect-specific Rust fixture matrices remain mandatory in task 2.1.
- **Contract recovery:** `design.md` no longer embeds mutable progress metrics. The recovery added only shared composition contracts and tests; it does not begin or claim parity for task 2.1 effects.

## Contract Reconciliation

- **Task 0.3 path:** `tasks.md` plans `Sources/ttfx-swift/Utils/`, but the implementation is `Sources/ttfx-swift/Core/ParityPrimitives.swift`. This is a package-local placement correction, not a behavior change: `design.md` explicitly assigns core primitives to `Sources/ttfx-swift/Core/*.swift`, and `swift-ttfx-core/spec.md` defines RNG, easing, geometry, gradients, and Python-compatible rounding as core capabilities. Keeping them in `TTFXCore` preserves the intended dependency direction and makes them available to effects without introducing a second utility target.
- **Parity fixture tool path:** `parity-harness/spec.md` references the generic legacy path `tools/gen_fixtures.sh`; the concrete Swift-port tool is `tools/swift-parity/generate-fixtures.sh`, as anticipated by `design.md`'s `tools/swift-parity/` path. The dedicated directory avoids modifying or conflating Rust tooling. Its harness exercises `FixtureGenerator`, which resolves the local Git revision and invokes an explicit oracle executable plus argument array through `ProcessRunner`; no composed shell command is accepted by the parity API. The full persisted effect matrix remains deferred until the effects required to generate it exist.

## Exact Phase 0 File Inventory

| File | Action | Phase 0 responsibility |
|---|---|---|
| `Package.swift` | Modified | Replaced the empty combined target and inaccessible ANSI dependency with `TTFXCore`, `TTFXEffects`, `TTFXCLI`, direct test target, supported platforms, and ArgumentParser. |
| `Package.resolved` | Created | Pinned `swift-argument-parser` 1.8.2 for reproducible package resolution. |
| `Sources/ttfx-swift/CLI/main.swift` | Created | Added the minimal buildable `ttfx` executable entry point. |
| `Sources/ttfx-swift/Core/TTFXCore.swift` | Created | Added `Cell`, `Frame`, `Canvas`, input models, effect contract, and tick status. |
| `Sources/ttfx-swift/Core/ParityPrimitives.swift` | Created | Added Xoshiro256++, compatibility math, easing, geometry, colors, and gradients in the `TTFXCore` module. |
| `Sources/ttfx-swift/Core/ParityHarness.swift` | Created | Added ProcessRunner, revision-pinned fixture generation, frame-dump decoding, and byte/cell mismatch diagnostics. |
| `Sources/ttfx-swift/Effects/TTFXEffects.swift` | Created | Added the empty effects-module seam depending on `TTFXCore`. |
| `tests/ttfx-swiftTests/Core/PackageBaselineTests.swift` | Created | Proved the restored core module is linkable. |
| `tests/ttfx-swiftTests/Core/CorePrimitivesTests.swift` | Created | Covered Cell layout, Frame mutation, Unicode ingestion, coordinates, and effect protocol conformance. |
| `tests/ttfx-swiftTests/Core/ParityPrimitivesTests.swift` | Created | Covered deterministic RNG, compatibility math, geometry, gradients, easing endpoints, and mapping order. |
| `tests/ttfx-swiftTests/Parity/ParityHarnessTests.swift` | Created | Covered subprocess threat cases, Git roots, dump decoding, and fixture generation. |
| `tests/ttfx-swiftTests/Parity/CoreParityScenariosTests.swift` | Created | Covered cell mismatch diagnostics, empty/undersized canvas input, invalid dimensions, and a second RNG seed. |
| `tools/swift-parity/generate-fixtures.sh` | Created | Added the Swift-port parity-harness entry point without modifying existing Rust tools. |
| `openspec/changes/native-swift-port/tasks.md` | Modified | Marked only Phase 0 tasks 0.1–0.5 complete. |
| `openspec/changes/native-swift-port/apply-progress.md` | Created and modified | Persisted cumulative strict-TDD, work-unit, reconciliation, workload, and inventory evidence. |

## Exact Phase 1 File Inventory

| File | Action | Phase 1 responsibility |
|---|---|---|
| `Sources/ttfx-swift/Core/TTFXCore.swift` | Modified | Added configuration text/seed, `EffectConfig` alias, bounded tick-run result, fixed-storage capacity, and direct mutable-cell access. |
| `Sources/ttfx-swift/Core/EffectEngine.swift` | Created | Added deterministic generic effect initialization, single-tick state machine, and bounded tick execution. |
| `tests/ttfx-swiftTests/Core/EffectInitializationTests.swift` | Created | Proved deterministic scalar decomposition, initial frame state, seed preservation, and empty input behavior. |
| `tests/ttfx-swiftTests/Core/EffectTickTests.swift` | Created | Proved running/complete transitions and no effect invocation after completion. |
| `tests/ttfx-swiftTests/Core/EffectPerformanceTests.swift` | Created | Added the 500-tick 200x50 deterministic time and fixed-capacity proxy. |
| `openspec/changes/native-swift-port/tasks.md` | Modified | Marked only tasks 1.1–1.3 complete after focused and full Swift evidence passed. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Merged Phase 1 cumulative evidence, deviations, and exact inventory without removing Phase 0 evidence. |

## Exact Phase 2.0 File Inventory

| File | Action | Phase 2.0 responsibility |
|---|---|---|
| `Sources/ttfx-swift/Core/AnimationSubstrate.swift` | Created | Added value-oriented `CharacterID`, `CharacterState`, `MotionPath`, `AnimationScene`, typed events, ordered `TerminalModel`, seeded `AnimationRuntime`, and collision renderer. |
| `tests/ttfx-swiftTests/Core/AnimationSubstrateTests.swift` | Created | Added seven RED→GREEN substrate tests for all task 2.0 behaviors and deterministic seeded runtime scheduling. |
| `openspec/changes/native-swift-port/tasks.md` | Modified | Marked only task 2.0 complete after focused and full Swift evidence passed. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Merged Phase 2.0 strict-TDD, runtime, capacity-limitation, rollback, rationale, and inventory evidence without removing prior waves. |

## Exact Phase 2.0a File Inventory

| File | Action | Phase 2.0a responsibility |
|---|---|---|
| `Sources/ttfx-swift/Core/MotionComposition.swift` | Created | Added ordered multi-segment paths, easing, holds, resettable cursors, and path chains. |
| `Sources/ttfx-swift/Core/SceneComposition.swift` | Created and modified | Added synchronized/resettable scene playback, static/dynamic preexisting-color gradients, and terminal completion state. |
| `Sources/ttfx-swift/Core/CharacterScheduling.swift` | Created and modified | Added input-to-arena initialization, append-only spawning, canonical grouping, delayed releases, and release-plan completion. |
| `Sources/ttfx-swift/Core/RuntimeActions.swift` | Created and modified | Added ordered typed actions, non-persistent closure chain draining, and deterministic action lookup for runtime execution. |
| `Sources/ttfx-swift/Core/EffectRuntime.swift` | Created and modified | Added build-once runtime effect integration with schedule/update/render lifecycle and typed inline emitted-event delivery. |
| `Sources/ttfx-swift/Core/AnimationSubstrate.swift` | Modified | Added runtime build state, named deterministic RNG value trace, emitted events, and active composed-work update integration. |
| `Sources/ttfx-swift/Core/RuntimeExecution.swift` | Created and modified | Added executable composed paths/scenes, typed runtime action dispatch, Rust-compatible named random operations, assigned paths, anchors, retirement, release pruning, and scene completion. |
| `tests/ttfx-swiftTests/Core/AnimationCompositionTests.swift` | Created and modified | Added eleven RED→GREEN composition, dynamic-gradient, contract-recovery, and Rust-derived trace tests. |
| `tests/ttfx-swiftTests/Core/RuntimeExecutionTests.swift` | Created and modified | Added ten strict-TDD integration tests for shared-runtime execution and contract recovery. |
| `openspec/config.yaml` | Modified | Reconciled stale Swift testing availability and apply command with the proven runnable package. |
| `openspec/changes/native-swift-port/tasks.md` | Modified | Marked only task 2.0a complete after all gates passed. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Merged cumulative Phase 2.0a evidence without removing prior waves. |
| `openspec/changes/native-swift-port/design.md` | Modified | Removed stale mutable progress metrics from the architecture text. |

## Remaining Tasks

- [ ] 2.1–2.5 All-effect parity waves.
- [ ] 3.1–3.4 CLI and ANSI parity.
- [ ] 4.1–4.3 Optional SwiftUI renderer.
- [ ] 5.1–5.5 release, CI, fixtures, and final parity.

## Workload

- Current cumulative impact is reconciled in the contract-gap recovery inventory below. The 671-word design remains within its 800-word cap. Later batches MUST recompute this union from current file line counts after updating their exact inventory; exclude directories, `.build/`, `.codegraph/`, and unrelated local files.
- Delivery remains the approved single-PR `size:exception`; this work unit is self-contained and reversible at the listed rollback boundary.

## Phase 2 Effect Oracle Contract-Gap Recovery

This recovery corrects only the rejected effect-oracle boundary. It adds no named Swift effect, changes no Rust production source, leaves task 2.1 unchecked, and preserves the cumulative 10/27 state.

### TDD Cycle Evidence

| Scope | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Fixture provenance, content, and regeneration | `Tests/ttfx-effectsTests/EffectOracleFixtureTests.swift` | Rust-backed integration | `swift test --filter EffectOracleFixtureTests` — exit 0; 1 test passed before edits. | Valid RED: the same command exited 1 with 18 issues: decoded manifest input was literal `Swift\\nTTE`; wipe/bubbles/swarm were blank and non-varying; generator check emitted no success receipt. The first compile-only attempt was corrected before this executable RED because `#expect` cannot contain a right-hand `try`. | Exit 0; 2 tests passed after fixed Rust options, decoded newline manifest input, atomic regenerate/check, and transitive target cleanup. | Eight exact names; seven 32-frame dumps plus one 18-frame dump; each requires a nonblank visible frame and more than one visible frame. | No behavior-preserving code extraction was warranted; reran the focused test after the dependency cleanup. |
| Exact Rust range, choice/rejection, and shuffle trace | `tests/ttfx-swiftTests/Core/EffectOraclePrimitivesTests.swift` | Unit/oracle fixture | `swift test --filter EffectOraclePrimitivesTests` — exit 0; 3 tests passed before edits. | Exit 1 because `tests/fixtures/rng/rust-seed-42-range-choice-shuffle.json` did not exist; a second RED exited 1 because its mandatory `source` provenance field did not exist. | Exit 0; 3 tests passed after adding the revision-pinned Rust trace fixture. | Pins inclusive, half-open, choice rejection, and all three Fisher-Yates draws rather than comparing a second Swift runtime. | Replaced the former Swift-vs-Swift determinism assertion with direct fixture values; no production refactor was needed. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused fixture test | `swift test --filter EffectOracleFixtureTests` — exit 0; 2 Swift Testing tests passed. |
| Focused primitives test | `swift test --filter EffectOraclePrimitivesTests` — exit 0; 3 Swift Testing tests passed. |
| Full result | `swift test` — exit 0; 53 Swift Testing tests passed. |
| Runtime/oracle harness | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0, generated eight temporary Rust dumps and reported `Effect oracle fixtures are current.`; `--regenerate` — exit 0, atomically replaced the corpus and reported revision `6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a`; the following `--check` exited 0 with the same current receipt. |
| Diff whitespace | `git diff --check` — exit 0. Git reports only `.gitignore` as a tracked diff; it is outside this recovery. |
| Rollback boundary | Revert `Package.swift`, `Tests/ttfx-effectsTests/EffectOracleFixtureTests.swift`, `tests/ttfx-swiftTests/Core/EffectOraclePrimitivesTests.swift`, `tests/fixtures/effects/`, `tests/fixtures/rng/rust-seed-42-range-choice-shuffle.json`, `tools/swift-parity/generate-effect-oracles.sh`, and this recovery section. This removes no named effect because none was added. |

### Corpus and Primitive Provenance

The generator obtains `git rev-parse HEAD`, validates a 40-character lowercase hexadecimal revision, writes every dump and manifest into a sibling staging directory, and replaces the complete effects directory only after all Rust commands succeed. `--check` independently regenerates the same staging corpus and byte-compares its manifest and all eight dumps, so a different current HEAD, input encoding, options, frame bytes, or file set fails closed.

| Effect | Exact frame count | First nonblank frame (zero-based) | Distinct visible frames |
|---|---:|---:|---:|
| print | 32 | 0 | 30 |
| slide | 32 | 3 | 6 |
| wipe | 32 | 3 | 5 |
| expand | 18 | 0 | 11 |
| rain | 32 | 0 | 19 |
| bubbles | 32 | 6 | 16 |
| fireworks | 32 | 0 | 9 |
| swarm | 32 | 25 | 6 |

The manifest decodes its input to exactly `Swift` followed by a newline and `TTE`, rather than a backslash-plus-`n` sequence. Wipe uses the Rust-supported `out_expo`, one-step, one-frame options; bubbles uses speed `3` and delay `1`; swarm uses size/coordination `1` and area range `1-1`. These fixed options are not fabricated frames: they only bound a real 32-frame Rust run so each delayed effect includes a transition.

`tests/fixtures/rng/rust-seed-42-range-choice-shuffle.json` is pinned to the same revision and cites `src/utils/rng.rs:57-105; tools/parity/shim.py:57-83`. For seed 42 it requires choice `[10,20,30] → 20` after raw rejected/accepted draws `15021278609987233951`, `5881210131331364753`; closed `-2...2 → 2`; half-open `5..<9 → 5`; and Rust Fisher-Yates `[1,2,3,4] → [4,2,1,3]` with raw shuffle draws `11162538943635311430`, `3831705504650218695`, `17217215411128672468`.

### Repository Artifact Union and Line Accounting

The recomputed native Swift/OpenSpec artifact union contains exactly 55 paths:

- `Package.resolved`, `Package.swift`
- `Sources/ttfx-swift/CLI/main.swift`
- `Sources/ttfx-swift/Core/AnimationSubstrate.swift`, `CharacterScheduling.swift`, `EffectEngine.swift`, `EffectRuntime.swift`, `MotionComposition.swift`, `ParityHarness.swift`, `ParityPrimitives.swift`, `RuntimeActions.swift`, `RuntimeExecution.swift`, `SceneComposition.swift`, `TTFXCore.swift`
- `Sources/ttfx-swift/Effects/TTFXEffects.swift`, `PrintEffect.swift`, `SlideEffect.swift`, `WipeEffect.swift`, and `ExpandEffect.swift`
- `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, `EffectOracleFixtureTests.swift`
- `tests/ttfx-swiftTests/Core/AnimationCompositionTests.swift`, `AnimationSubstrateTests.swift`, `CorePrimitivesTests.swift`, `EffectInitializationTests.swift`, `EffectOraclePrimitivesTests.swift`, `EffectPerformanceTests.swift`, `EffectTickTests.swift`, `PackageBaselineTests.swift`, `ParityPrimitivesTests.swift`, `RuntimeExecutionTests.swift`
- `tests/ttfx-swiftTests/Parity/CoreParityScenariosTests.swift`, `ParityHarnessTests.swift`
- `tests/fixtures/effects/bubbles.frames`, `expand.frames`, `fireworks.frames`, `manifest.json`, `print.frames`, `rain.frames`, `slide.frames`, `swarm.frames`, `wipe.frames`, and `tests/fixtures/rng/rust-seed-42-range-choice-shuffle.json`
- `tools/swift-parity/generate-effect-oracles.sh`, `tools/swift-parity/generate-fixtures.sh`
- `openspec/config.yaml`, `openspec/changes/native-swift-port/{apply-progress,design,proposal,tasks}.md`, and its five `specs/*/spec.md` files.

The union excludes generated `.build/**`, `.codegraph/**`, and unrelated local paths. Because these 55 artifacts are untracked in this workspace, Git cannot prove their changed-file identity: `git diff --numstat` contains only the unrelated tracked `.gitignore` line. This is a filesystem inventory and direct-work record, not a claim of Git history or a Git-derived changed-file set.

| Bucket | Paths | Physical lines |
|---|---:|---:|
| Package and Swift production sources | 19 | 3,182 |
| Swift tests | 14 | 1,510 |
| Effect and RNG fixtures | 10 | 1,736 |
| Fixture tools | 2 | 97 |
| OpenSpec configuration and active-change artifacts | 10 | 1,081 |
| **Complete 55-path union** | **55** | **7,606** |

## Phase 2 Simple Effects — RED Boundary

This partial work unit is not complete. Task 2.1 remains unchecked at 10/27, and no named Swift effect source was added. `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` contains one dedicated Rust-frame parity test for each of `PrintEffect`, `SlideEffect`, `WipeEffect`, and `ExpandEffect`. Each constructs the named effect with the admitted manifest input, seed, canvas, and input scalars, ticks an actual `Frame`, serializes its cell foreground ANSI encoding, and compares every tick to the corresponding revision-pinned Rust dump.

| Effect | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|
| print_effect | `swift test --filter EffectOracleFixtureTests` — exit 0; 2 passed. | `swift test --filter printEffectMatchesItsAdmittedRustFrames` — exit 1: `PrintEffect` is absent; the dedicated test therefore cannot execute or pass through type-only availability. | Blocked — no implementation written. | Blocked — no admitted second Rust case is available until the first parity implementation exists. | N/A — no production code to refactor. |
| slide | Same safety net. | The same RED compile reports `SlideEffect` absent in its dedicated fixture-parity test. | Blocked. | Blocked. | N/A. |
| wipe | Same safety net. | The same RED compile reports `WipeEffect` absent in its dedicated fixture-parity test. | Blocked. | Blocked. | N/A. |
| expand | Same safety net. | The same RED compile reports `ExpandEffect` absent in its dedicated fixture-parity test. | Blocked. | Blocked. | N/A. |

The RED test is deliberately not a type smoke test: after construction it invokes `tick(into:)`, serializes the resulting cells including RGB SGR bytes, and compares each complete tick to the Rust fixture. It cannot be admitted as GREEN without real per-effect scheduling, movement, gradients, color state, and completion behavior. It reads fixtures only from test support; production code does not read fixture bytes.

### Blocked Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused RED command | `swift test --filter printEffectMatchesItsAdmittedRustFrames` — exit 1; compilation reports all four named effect types absent. |
| Runtime harness | N/A — named effects have no implementation to execute. The existing Rust fixture generator and corpus were not changed. |
| Rollback boundary | Remove `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` and this section; no source, fixture, generator, task, or configuration change requires rollback. |
| Remaining assigned scope | Implement only `print_effect`, `slide`, `wipe`, and `expand` with independent GREEN and direct Rust-derived triangulation; do not start rain, bubbles, fireworks, swarm, or task 2.2+. |

### Pending Inventory Reconciliation

This historical pre-effect snapshot is superseded by the 55-path, 7,606-line cumulative union above. Task 2.1 remains unchecked.

## Phase 2 PrintEffect Work Unit

This is a partial implementation of task 2.1 only. The task 2.1 checkbox remains unchecked and the cumulative checkbox state remains 10/27; no slide, wipe, expand, rain, bubbles, fireworks, swarm, CLI, or later-task implementation was added.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `print_effect` | `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | Intentional existing RED: the first focused invocation was required to fail because `PrintEffect` did not exist. | `swift test --filter printEffectMatchesItsAdmittedRustFrames` exited 1 with `cannot find 'PrintEffect' in scope` at lines 52 and 61 before source was added; after the future named REDs were conditionally isolated, the same command exited 1 only for absent `PrintEffect` at lines 61 and 84. | Initial genuine implementation reached tick 11 but failed `actual 327 bytes` versus `expected 304 bytes` because the carriage-return head retained white SGR; after clearing return-head color, tick 15 failed `actual 400 bytes` versus `expected 375 bytes` because inner fill cells were incorrectly typed. Reproducing Rust's per-row right extent produced exit 0 for all admitted 32 frames. The completion assertion then correctly went RED with Swift `.running` after Rust's 24th/last frame; advancing past the final row before evaluating pending work restored `.complete`. | `printEffectMatchesAnIndependentRustRun` executes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 40 --seed 7 --ignore-terminal-dimensions --canvas-width 7 --canvas-height 4 print` with stdin `Hi\nZ`; Rust emitted 24 frames and the test compares every Swift tick byte-for-byte, then asserts matching Swift completion. | Replaced the machine-specific Cargo path with `/usr/bin/env` plus inherited environment, removed an unused glyph field, added the completion check, and reran the focused tests. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused test command | `swift test --filter printEffect` — exit 0; 2 Swift Testing tests passed: the admitted 12×6/seed-42 32-frame corpus and the independent 7×4/seed-7 Rust run with 24 frames. |
| Full suite | `swift test` — exit 0; 55 Swift Testing tests passed. Future named RED tests are retained behind `#if TTFX_FUTURE_EFFECTS`, so the target compiles independently without fake effect types or implementations. |
| Runtime/oracle harness | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; Rust generated seven 32-frame dumps and one 18-frame dump, then reported `Effect oracle fixtures are current.` No fixture was read by production code. |
| Diff whitespace | `git diff --check` — exit 0. The repository still has unrelated pre-existing `.gitignore` modification and untracked Swift/OpenSpec artifacts. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/PrintEffect.swift` and revert the PrintEffect/conditional-isolation additions in `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` plus this section. This restores the original PrintEffect RED boundary and removes no other effect behavior. |

### PrintEffect Implementation Notes

`PrintEffect` uses `TTFXCore` canvas/input/frame, gradient, easing, coordinate, and Python-compatible half-even rounding primitives. It reproduces the Rust defaults: speed 2, return speed 1.5, `in_out_quad`, final diagonal gradient stops `02b8bd c1f0e3 00ffa0` with 12 steps, three ticks per fade visual, canvas-wide outer-fill row handling, row-specific right extent, completed-row shifts, uncolored carriage-return head, and terminal cell ordering. Input preexisting ANSI colors and effect-specific option plumbing are not representable by the current `EffectConfiguration`/`InputText` contract; the implemented public construction exactly covers the admitted static-color default configuration.

### Exact Work Unit Inventory and Accounting

| File | Action | Physical lines at subunit completion | Responsibility |
|---|---|---:|---|
| `Sources/ttfx-swift/Effects/PrintEffect.swift` | Created | 260 | Genuine static-default Rust `print_effect` state machine, fades, gradients, carriage return, render order, and completion. |
| `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Modified | 134 | Preserves per-tick ANSI byte comparison, adds first-mismatch visible-grid diagnostics, direct live-Rust triangulation/completion, and compile isolation for future named REDs. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Self-referential | Persists cumulative strict-TDD, proof, rollback, and remaining-scope evidence. |

At subunit completion, the implementation/test inventory was exactly 2 files and 394 physical lines. The current cumulative accounting is the 55-path union above.

### Remaining Effects and Task State

- [ ] 2.1 remains unchecked: `SlideEffect`, `WipeEffect`, `ExpandEffect`, `RainEffect`, `BubblesEffect`, `FireworksEffect`, and `SwarmEffect` still require their own RED→GREEN Rust parity work units.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 Simple Effects Contract-Gap Correction

This correction changes only evidence tests, source quirk references, and cumulative accounting for the completed Print, Slide, Wipe, and Expand subunits. It adds no particle effect, no later task, no Rust production change, and no generator behavior change. Task 2.1 remains unchecked at 10/27.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `phase-2-simple-effects-contract-gaps` | `tests/ttfx-effectsTests/{EffectFrameParityTests,EffectOracleFixtureTests}.swift` | Rust-frame integration/provenance | `swift test --filter 'printEffect|slideEffect|wipeEffect|expandEffect'` — exit 0; 9 tests passed before the correction. | The initial completion classification asserted Expand's 18-frame admitted dump was `.running`; it failed because tick 18 returned `.complete`. This exposed the prior discarded-status gap and established the correct terminal classification without changing effect behavior. | `swift test --filter 'printEffect|slideEffect|wipeEffect|expandEffect|effectOracleGeneratorMatchesRecordedUntrackedHashBaseline'` — exit 0; 10 tests passed after direct status and total-tick assertions, plus the read-only hash baseline test. | Every admitted prefix now proves all prior ticks remain `.running`; Print/Slide/Wipe end `.running` with no completion tick, while Expand completes exactly on tick 18. Independent live Rust runs prove completion exactly at ticks 24, 25, 205, 101, and 6 respectively. | Added concise `QUIRK(...)` references to the three missing source files and preserved Wipe's marker; no production behavior refactor was needed. |

### Completion Classification

`FrameParityResult` records both the final `TickStatus` and the first completion tick. It asserts `.running` on every non-final compared tick, so a Swift effect cannot silently complete before the Rust frame corpus ends.

| Effect | Admitted corpus | Admitted classification | Completion evidence |
|---|---:|---|---|
| Print | 32 frames | Prefix-capped: final `.running`, no completion tick. | Live Rust `Hi\nZ`, 7×4, seed 7: `.complete` first occurs on tick 24. |
| Slide | 32 frames | Prefix-capped: final `.running`, no completion tick. | Live configured Rust run, 7×4, seed 7: `.complete` first occurs on tick 25. |
| Wipe | 32 frames | Prefix-capped: final `.running`, no completion tick. | Live resetting and outside-to-center Rust runs complete first on ticks 205 and 101. |
| Expand | 18 frames | Terminal: ticks 1–17 are `.running`; tick 18 is `.complete`. The generator ceiling is 32, so this dump is not a prefix-cap completion claim. | Live configured Rust run, 9×5, seed 7: `.complete` first occurs on tick 6. |

### Generator Hash Provenance

`effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` reads only `tools/swift-parity/generate-effect-oracles.sh` and requires SHA-256 `eddd01eea46729d3061b7c889afcc7daf91409c3490e823f5180a77baec8f820`. The baseline records the generator's current bytes at this correction boundary and is intentionally not presented as Git history: the generator is untracked in this workspace. A future byte change fails the read-only provenance test until its scope and hash are deliberately reconciled here.

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused tests | `swift test --filter 'printEffect|slideEffect|wipeEffect|expandEffect|effectOracleGeneratorMatchesRecordedUntrackedHashBaseline'` — exit 0; 10 Swift Testing tests passed. |
| Runtime/oracle harness | The five existing argument-array live Rust scenarios compared every fresh Swift frame and proved final completion at 24 Print, 25 Slide, 205/101 Wipe, and 6 Expand ticks. No new runtime boundary was introduced. |
| Provenance/hash check | `swift test --filter effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` — required in the final validation; it invokes `/usr/bin/shasum -a 256` read-only against the generator. |
| Rollback boundary | Revert the completion-classification additions in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the hash test in `Tests/ttfx-effectsTests/EffectOracleFixtureTests.swift`, the `QUIRK(...)` comments in the four effect sources, and this correction/index/accounting evidence. This retains all four effect algorithms, fixtures, generator bytes, and the unchecked task 2.1 state. |

### Task State

- [ ] 2.1 remains unchecked: RainEffect, BubblesEffect, FireworksEffect, and SwarmEffect are not implemented by this correction.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 Simple Effects Documentary Gate

This unit changes only `QUIRK(...)` planning-file provenance and durable receipts. It does not implement Rain, Bubbles, Fireworks, Swarm, CLI, SwiftUI, or later tasks. WipeEffect algorithm is unchanged. Task 2.1 remains unchecked at 10/27. No fixture, generator, or Rust production bytes were modified.

Print, Slide, and Expand `QUIRK(...)` comments previously cited only Rust source ranges. They now also reference `plan.md`, matching the swift-effects-parity requirement that every quirk marker cite `plan.md` or `ordering-inventory.md`. Wipe already cited `ordering-inventory.md` and was left unchanged.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `phase-2-simple-effects-documentary-gate` | existing `EffectOracleFixtureTests` / `EffectFrameParityTests` | Documentary provenance | `swift test --filter effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` — exit 0; 1 test passed after comment edits. | No new production behavior. Comment-only provenance cannot go RED without changing tests, which this unit forbids. | Comment updates compile; the standalone hash filter remains 1 passing test. Full-suite GREEN is blocked by a pre-existing HEAD/fixture revision mismatch, not by the comments. | Triangulation skipped: one documentary form with no branching behavior. | None. Wipe algorithm, fixtures, and generator bytes were not refactored. |

### Persisted Receipts

| Evidence | Exact result |
|---|---|
| Standalone hash | `swift test --filter effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` — exit 0; Swift Testing ran 1 test, 1 passed. |
| Post-correction full suite | `swift test` — exit 1; Swift Testing ran 63 tests in 1 suite and failed after 4.313 seconds with 4 issues. 60 tests passed. Three tests failed because current `git rev-parse HEAD` is `f544dc813eff97c4310df1f91629d8e834afb683` (`chore(wip): checkpoint native Swift port`) while fixtures remain pinned to `6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a`. Failures: `effectOracleFixturesHavePinnedProvenanceAndBehavioralContent`, `namedRandomOperationsMatchPinnedRustRangeChoiceAndShuffleTrace`, and `effectOracleGeneratorCheckIsDeterministicAndReportsCurrentFixtures`. All Print/Slide/Wipe/Expand admitted and live-Rust parity tests passed. |
| Post-correction generator check | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 1; emitted `frames=32` seven times, `frames=18` once, then `Effect oracle fixtures are stale or pinned to a different Rust revision.` |
| Diff whitespace | `git diff --check -- Sources/ttfx-swift/Effects/{Print,Slide,Expand}Effect.swift openspec/changes/native-swift-port/apply-progress.md` — exit 0. |
| Task checkboxes | Unchanged. `tasks.md` still shows `- [ ] 2.1`. |
| Rollback boundary | Revert the `plan.md` additions in the Print/Slide/Expand `QUIRK(...)` comments and this documentary-gate section. Leave Wipe, fixtures, generator bytes, and task 2.1 untouched. |

The previously missing standalone hash, full-suite, and generator-check receipts are now persisted as observed. They are not invented passing results: after the checkpoint commit, the oracle revision pin and current HEAD no longer match. Closing the remaining receipt gap requires an authorized fixture-revision reconciliation, which this unit forbids.

### Task State

- [ ] 2.1 remains unchecked: RainEffect, BubblesEffect, FireworksEffect, and SwarmEffect are not implemented by this documentary unit.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 ExpandEffect Work Unit

This partial task 2.1 work unit implements only `ExpandEffect`. Task 2.1 remains unchecked at 10/27 because rain, bubbles, fireworks, and swarm remain pending. PrintEffect, SlideEffect, WipeEffect, Rust production source, fixture-generation behavior, CLI work, and later tasks were preserved.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `expand` | `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | `swift test --filter printEffect` exit 0, 2 passed; `swift test --filter slideEffect` exit 0, 2 passed; `swift test --filter wipeEffect` exit 0, 3 passed. | Activated the admitted 18-frame Expand test; `swift test --filter expandEffectMatchesItsAdmittedRustFrames` exited 1 because `ExpandEffect` was absent. After adding the independent test, `swift test --filter expandEffect` again exited 1 with both calls unable to find `ExpandEffect`. | Added a standalone configurable `ExpandEffect`; `swift test --filter expandEffect` exit 0, 2 passed, comparing all 18 admitted ANSI frames and exact completion. | `expandEffectMatchesAConfiguredIndependentRustRun` invokes Rust through argument-array `ProcessRunner` with input `AB\nC`, canvas 9×5, seed 7, `out_sine`, speed 0.9, horizontal `112233 → 445566` colors, and four gradient steps. Rust emitted 6 frames; the test compares every ANSI byte and requires Swift `.complete`. Together with the admitted 12×6/seed-42 trace, this exercises canvas-center origins, active-path layer precedence, distance-synchronized color selection, easing, final gradient mapping, and completion. | Reused the center coordinate per tick and made the key-path predicate idiomatic; reran the focused tests. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Expand test | `swift test --filter expandEffect` — exit 0; 2 Swift Testing tests passed: the admitted 12×6/seed-42 18-frame fixture and the independent 9×5/seed-7 6-frame configured Rust run. |
| Safety tests | `swift test --filter printEffect` — exit 0; 2 passed. `swift test --filter slideEffect` — exit 0; 2 passed. `swift test --filter wipeEffect` — exit 0; 3 passed. |
| Full Swift suite | `swift test` — exit 0; 62 Swift Testing tests passed. |
| Runtime/oracle harness | The independent test uses `/usr/bin/env cargo run --quiet -- --parity-dump ... expand` via `ProcessRunner`, inherited environment, repository-root working directory, and a 30-second timeout. It emitted 6 length-prefixed terminal frames and compared every frame to a fresh Swift `Frame`; the admitted fixture comparison covers 18 frames. Production code never reads fixture data. |
| Fixture generator | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; Rust reported `frames=32` for seven effects, `frames=18` for Expand, and `Effect oracle fixtures are current.` |
| Diff whitespace | `git diff --check` — exit 0. The only tracked pre-existing diff is `.gitignore`; Swift/OpenSpec artifacts are untracked in this workspace. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/ExpandEffect.swift`; revert the Expand activation and independent Rust test in `Tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section/top-level work-unit entry. This leaves Print, Slide, Wipe, Rust, fixtures, generator, and all pending effects intact. |

### Expand Implementation Notes

`ExpandEffect` is a distinct `Effect`, not an alias or fixture reader. It starts every input glyph at Rust's parity-compatible canvas center, advances each line path with the configured easing and half-even step count, gives active paths layer 1, resolves collisions by layer then insertion order, and selects foreground colors from the path-distance-synchronized ten-step scene gradient. Once a path settles, it restores layer 0, renders the final gradient color, and reports completion on the final emitted frame. The configuration exposes movement easing/speed and final gradient stops/steps/direction.

### Exact Work Unit Inventory and Accounting

| File | Action | Physical lines at subunit completion | Responsibility |
|---|---|---:|---|
| `Sources/ttfx-swift/Effects/ExpandEffect.swift` | Created | 182 | Configurable center-origin movement, active-path layers, distance-synchronized colors, collision rendering, and exact completion. |
| `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Modified | 312 | Activates the admitted Expand RED and adds the 6-frame live Rust configuration test while preserving Print, Slide, and Wipe coverage. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Self-referential | Merges strict-TDD, frame-count, runtime, rollback, and remaining-scope evidence. |

At subunit completion, the direct Expand source was 182 physical lines. The current cumulative accounting is the 55-path union above.

### Remaining Effects and Task State

- [ ] 2.1 remains unchecked: RainEffect, BubblesEffect, FireworksEffect, and SwarmEffect require their own RED→GREEN Rust parity work units.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 WipeEffect Work Unit

This partial task 2.1 work unit implements only `WipeEffect`. Task 2.1 remains unchecked at 10/27: `ExpandEffect`, `RainEffect`, `BubblesEffect`, `FireworksEffect`, and `SwarmEffect` remain unimplemented. PrintEffect and SlideEffect behavior, Rust production source, fixtures, generator behavior, CLI, and later tasks were preserved.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `wipe` | `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | `swift test --filter printEffect` — exit 0, 2 tests passed; `swift test --filter slideEffect` — exit 0, 2 tests passed. | Activated the existing admitted 32-frame Wipe test; `swift test --filter wipeEffectMatchesItsAdmittedRustFrames` exited 1 because `WipeEffect` was absent. The later all-direction RED exited 1 because `.outsideToCenter` was absent. | Added a distinct configurable `WipeEffect`; the admitted Rust fixture command exited 0 and compared all 32 ANSI frames. The fixture is intentionally capped, so its 32nd Swift status is `.running`. | `wipeEffectMatchesAResettingIndependentRustRun` runs live Rust with input `AB\nCDE`, canvas 7×4, seed 7, reverse diagonal ordering, delay 1, `out_bounce`, horizontal `112233 → 445566`, two steps, and two frames per step. Rust emitted 205 frames; the test compares every ANSI frame and Swift returns `.complete`. The non-monotonic ease exercises add/remove/reset/re-add behavior. `wipeEffectMatchesAnOutsideToCenterRustRun` then proves the center-distance ordering with input `A\nBC`, canvas 6×4, seed 11, and 101 live Rust frames. | Extracted activation and remove/reset operations, documented the non-monotonic `SequenceEaser` quirk, normalized the key-path spelling, completed the ten Rust direction variants with center-distance grouping, and placed live-Rust parity tests in a serialized Swift Testing suite after concurrent Cargo runs timed out. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Wipe tests | `swift test --filter wipeEffect` — exit 0; 3 Swift Testing tests passed: the admitted 12×6/seed-42 32-frame corpus, the independent 7×4/seed-7 205-frame resetting Rust run, and the 6×4/seed-11 101-frame outside-to-center Rust run. |
| Print/Slide safety | `swift test --filter printEffect` — exit 0; 2 tests passed. `swift test --filter slideEffect` — exit 0; 2 tests passed. |
| Full Swift suite | `swift test` — exit 0; 60 Swift Testing tests passed. |
| Runtime/oracle harness | The configured Wipe tests invoke `/usr/bin/env cargo run --quiet -- --parity-dump ... wipe` through `ProcessRunner` with argument-array execution, inherited environment, repository-root working directory, and a 30-second timeout. They decode and compare all 205 resetting and 101 outside-to-center Rust frames and prove final Swift completion. |
| Fixture generator | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; reported `Effect oracle fixtures are current.` The admitted Wipe corpus remains 32 frames. |
| Diff whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/WipeEffect.swift`; revert the Wipe activation, admitted configuration, live-Rust test, and shared-helper return in `Tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. PrintEffect, SlideEffect, Rust source, fixtures, generator, task checkboxes, and all unimplemented effects remain intact. |

### Wipe Implementation Notes

`WipeEffect` is a standalone `Effect`, not a fixture reader or alias. It constructs canonical row/column-ordered groups, applies all ten Rust row, column, diagonal, and center-distance direction variants, advances Rust's 100-step clamped `SequenceEaser` policy, activates visible gradient scenes, and resets/hides removed groups before a later re-add. Its static color scenes use the core gradient coordinate mapping and exact ANSI frame serializer exercised by the test target. Production source contains no fixture access or hard-coded frame data.

### Exact Work Unit Inventory and Accounting

| File | Action | Physical lines at subunit completion | Responsibility |
|---|---|---:|---|
| `Sources/ttfx-swift/Effects/WipeEffect.swift` | Created | 259 | Configurable Wipe state machine: all ordered group directions, easing add/remove/reset, static gradients, ANSI-visible rendering, and completion. |
| `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Modified | 274 | Serializes live Rust parity invocations; activates the existing Wipe RED, configures the admitted corpus, and adds 205-frame reset and 101-frame outside-to-center live Rust parity/completion evidence while preserving Print/Slide tests. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Self-referential | Merges cumulative strict-TDD, runtime, inventory, rollback, and remaining-scope evidence. |

At subunit completion, the direct Wipe implementation/test inventory was 533 physical lines, including pre-existing Print/Slide parity coverage in the shared test file. The current cumulative accounting is the 55-path union above; task 2.1 remains unchecked.

### Remaining Effects and Task State

- [ ] 2.1 remains unchecked: `ExpandEffect`, `RainEffect`, `BubblesEffect`, `FireworksEffect`, and `SwarmEffect` require their own RED→GREEN Rust parity work units.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 SlideEffect Work Unit

This partial task 2.1 work unit implements only `SlideEffect`. Task 2.1 remains unchecked at 10/27: `WipeEffect`, `ExpandEffect`, `RainEffect`, `BubblesEffect`, `FireworksEffect`, and `SwarmEffect` remain unimplemented, and no PrintEffect behavior, fixture corpus, generator behavior, CLI, or later task was changed.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `slide` | `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | `swift test --filter printEffect` — exit 0; 2 PrintEffect tests passed before Slide edits. | Activated the dedicated admitted-fixture test outside the future-effect compilation gate; `swift test --filter slideEffectMatchesItsAdmittedRustFrames` exited 1 because `SlideEffect` was absent. | Added genuine `SlideEffect`; the same admitted 12×6/seed-42 test exited 0 and compared all 32 serialized ANSI frames. | Added `slideEffectMatchesAConfiguredIndependentRustRun`; its first RED exited 1 because `movementEasing` was unavailable. The final live-Rust scenario uses input `ACE\nB`, canvas 7×4, seed 7, diagonal grouping, merge, gap 1, speed 1.3, `out_sine`, horizontal `112233 → 445566` gradient, four gradient steps, and two frames per step. Rust emitted 25 frames; the test compares every ANSI frame and `.complete`. | Extracted configuration/easing state and corrected diagonal grouping to Rust's `(row,column)` bucket ordering and `column-row` key; reran both Slide tests after the refactor. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Slide tests | `swift test --filter slideEffect` — exit 0; 2 Swift Testing tests passed: 32 admitted fixture frames and 25 live Rust configured frames. |
| Print safety test | `swift test --filter printEffect` — exit 0; 2 Swift Testing tests passed, preserving the prior admitted 32-frame and independent 24-frame PrintEffect proofs. |
| Full Swift suite | `swift test` — exit 0; 57 Swift Testing tests passed. |
| Runtime/oracle harness | The configured Slide test invokes `/usr/bin/env cargo run --quiet -- --parity-dump ... slide` through `ProcessRunner` with argument-array execution, inherited environment, repository-root working directory, and a 30-second timeout. It compares each of Rust's 25 length-prefixed terminal frames to a fresh Swift `Frame`, then proves Swift completion on the final frame. |
| Fixture generator | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; regenerated eight temporary Rust dumps and reported `Effect oracle fixtures are current.` The admitted `slide.frames` corpus remains 32 frames. |
| Diff whitespace | `git diff --check` — exit 0. The implementation/test paths remain untracked in this workspace, so this check does not itself display their content. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/SlideEffect.swift`; revert the Slide activation, configured live-Rust test, and diagnostic-only failure output in `Tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. PrintEffect, Rust source, fixtures, generator, and task checkboxes remain intact. |

### Slide Implementation Notes

`SlideEffect` is an independent `Effect`, not a fixture reader or alias. It owns configurable row/column/diagonal grouping, gap, merge/reverse starts, movement speed/easing, static final-gradient stops/steps/frames/direction, path progress, per-character gradient scenes, terminal rendering, and completion. It uses the Rust-compatible geometry, half-even rounding, gradient, and ANSI-frame conventions already exposed by `TTFXCore`; production source does not access fixture files or hard-code any frame.

The admitted configuration has static input colors. The current `InputText` contract carries scalars and coordinates but no parsed ANSI preexisting colors, so dynamic existing-color handling is not exposed by this Swift effect boundary; no claim is made for that unavailable CLI/input mode.

### Exact Work Unit Inventory and Accounting

| File | Action | Physical lines at subunit completion | Responsibility |
|---|---|---:|---|
| `Sources/ttfx-swift/Effects/SlideEffect.swift` | Created | 352 | Genuine configurable Rust-parity Slide state machine: grouping, off-canvas starts, paths, gradients, rendering, and completion. |
| `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Modified | 179 | Activates the dedicated Slide RED test, adds 25-frame live-Rust triangulation, and improves mismatch ANSI diagnostics; existing Print tests remain behaviorally unchanged. |
| `openspec/changes/native-swift-port/apply-progress.md` | Modified | Self-referential | Merges cumulative strict-TDD, runtime, inventory, rollback, and remaining-scope evidence. |

At subunit completion, the direct Slide implementation/test inventory was 531 physical lines, including pre-existing Print parity coverage in the shared test file. The current cumulative accounting is the 55-path union above; task 2.1 stays unchecked.

### Remaining Effects and Task State

- [ ] 2.1 remains unchecked: `WipeEffect`, `ExpandEffect`, `RainEffect`, `BubblesEffect`, `FireworksEffect`, and `SwarmEffect` require their own RED→GREEN Rust parity work units.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 Oracle Revision Pin Reconciliation

Surgical work unit `phase-2-oracle-revision-pin-reconciliation` only. Task 2.1 remains unchecked at 10/27. No named Rain/other effect work, no Print/Slide/Wipe/Expand algorithm or QUIRK edits, and no admitted `*.frames` regeneration.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Recorded Rust pin after HEAD checkpoint | `tests/ttfx-effectsTests/EffectOracleFixtureTests.swift`, `tests/ttfx-swiftTests/Core/EffectOraclePrimitivesTests.swift` | Oracle provenance | Pre-edit HEAD was `f544dc813eff97c4310df1f91629d8e834afb683`; fixtures already recorded `6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a`. | `swift test --filter effectOracleFixturesHavePinnedProvenanceAndBehavioralContent --filter namedRandomOperationsMatchPinnedRustRangeChoiceAndShuffleTrace --filter effectOracleGeneratorCheckIsDeterministicAndReportsCurrentFixtures` — exit 1; 3 tests, 4 issues: fixture/RNG revision `6e24dac...` != `pinnedRevision` HEAD `f544dc8...`; `--check` status 1 with empty stdout. | Same three filters plus `effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` — exit 0; 4 tests passed after `FixtureGenerator.pinnedRevision` read the effects-manifest pin and the generator stopped using `git rev-parse HEAD`. | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; eight dump counts 32/32/32/18/32/32/32/32 and `Effect oracle fixtures are current.` `swift test --filter ParityHarnessTests` remains green via `rev-parse --git-dir` plus the recorded pin. | None; pin source is the existing manifest revision, not a new abstraction. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter effectOracleFixturesHavePinnedProvenanceAndBehavioralContent --filter namedRandomOperationsMatchPinnedRustRangeChoiceAndShuffleTrace --filter effectOracleGeneratorCheckIsDeterministicAndReportsCurrentFixtures` — exit 1; 3 failed / 4 issues. |
| GREEN focused | Same three filters plus `effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` — exit 0; 4 passed. |
| Generator check | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; `Effect oracle fixtures are current.`; dump bytes unchanged. |
| Full suite | `swift test` — exit 0; 63 Swift Testing tests passed. |
| Runtime harness | Generator `--check` still cargo-dumps the eight admitted effects into staging and byte-compares them to the recorded corpus; it now writes/compares pin `6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a` instead of current HEAD. |
| Rollback boundary | Revert `Sources/ttfx-swift/Core/ParityHarness.swift`, `tools/swift-parity/generate-effect-oracles.sh`, the hash literal in `tests/ttfx-effectsTests/EffectOracleFixtureTests.swift`, and this section. Fixtures, effect algorithms, and task 2.1 stay untouched. |

### Generator Hash Baseline

`effectOracleGeneratorMatchesRecordedUntrackedHashBaseline` now requires SHA-256 `d3f7843d92277de439d1ff7ad747ef4597546b6191a9b8bb988fb547a6737c15` for `tools/swift-parity/generate-effect-oracles.sh`. Previous baseline was `eddd01eea46729d3061b7c889afcc7daf91409c3490e823f5180a77baec8f820`.

### Remaining Tasks

- [ ] 2.1 Implement simple/particle: print_effect, slide, wipe, expand, rain, bubbles, fireworks, swarm in `Sources/ttfx-swift/Effects/`; dedicated tests: `tests/ttfx-swiftTests/Effects/`
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 RainEffect Work Unit

This partial task 2.1 work unit implements only `RainEffect`. Task 2.1 remains unchecked at 10/27 because bubbles, fireworks, and swarm remain pending. Print, Slide, Wipe, Expand, Rust production source, fixtures, generator behavior, CLI, and later tasks were preserved.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `rain` | `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | `swift test --filter printEffect --filter slideEffect --filter wipeEffect --filter expandEffect` — exit 0; 9 tests passed. | Existing admitted test compiled and failed: `swift test --filter rainEffectMatchesItsAdmittedRustFrames` exit 1, `cannot find 'RainEffect' in scope` at line 340. No extra closing brace was present. | First genuine implementation mismatched at tick 17 because fade index advanced on the same tick Rust still paints the popped frame. After matching `get_next_visual` (return current visual, then retire the frame), the admitted 12×6/seed-42 test exited 0 across all 32 ANSI frames with final status `.running`. | `rainEffectMatchesAConfiguredIndependentRustRun` runs live Rust with input `AB\nC`, canvas 8×5, seed 11, rain colors `112233 445566`, speed `2.0-2.5`, symbols `x +`, horizontal `88aaff → 00ffcc` steps 4, and `out_sine`. The dump is compared byte-for-byte and Swift returns `.complete` on the final frame. | Documented PathComplete→fade activation before scene stepping; no further production extraction. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Rain tests | `swift test --filter rainEffect` — exit 0; 2 Swift Testing tests passed: the admitted 12×6/seed-42 32-frame corpus and the independent configured live Rust run with completion. |
| Safety tests | `swift test --filter printEffect --filter slideEffect --filter wipeEffect --filter expandEffect` — exit 0; 9 tests passed. |
| Full Swift suite | `swift test` — exit 0; 65 Swift Testing tests passed (was 63). |
| Runtime/oracle harness | The independent test uses `/usr/bin/env cargo run --quiet -- --parity-dump ... rain` via `ProcessRunner`, inherited environment, repository-root working directory, and a 30-second timeout. Production code never reads fixture data. |
| Fixture generator | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; eight dump counts 32/32/32/18/32/32/32/32 and `Effect oracle fixtures are current.` Pin remains `6e24dac`. Generator script hash unchanged. |
| Diff whitespace | `git diff --check -- Sources/ttfx-swift/Effects/RainEffect.swift tests/ttfx-effectsTests/EffectFrameParityTests.swift` — exit 0. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/RainEffect.swift`; revert the Rain activation and independent Rust test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Print, Slide, Wipe, Expand, fixtures, generator, and pending effects remain intact. |

### Rain Implementation Notes

`RainEffect` is a standalone `Effect`, not a fixture reader or alias. It uses `Xoshiro256PlusPlus(seed)` with Rust `choice`/`uniform`/`randint` semantics, builds static final-gradient colors, draws per-character rain color then symbol then speed, groups by input row in BTreeMap order, and releases `randint(1, 2)` random pending glyphs each tick. Paths fall from `canvas.top` with `in_quart` by default; `PathComplete` activates the 7-step/3-duration fade in the same tick. Collisions use `(layer, character_id)`. The admitted fixture is capped at 32 frames so its last status is `.running`; completion is proved by the independent Rust run.

### Remaining Effects and Task State

- [ ] 2.1 remains unchecked: `BubblesEffect`, `FireworksEffect`, and `SwarmEffect` require their own RED→GREEN Rust parity work units.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 BubblesEffect Work Unit

This partial task 2.1 work unit implements only `BubblesEffect`. Task 2.1 remains unchecked at 10/27 because fireworks and swarm remain pending. Print, Slide, Wipe, Expand, Rain, Rust production source, fixtures, generator behavior, CLI, and later tasks were preserved.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `bubbles` | `Tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | `swift test --filter printEffect --filter slideEffect --filter wipeEffect --filter expandEffect --filter rainEffect` — exit 0; 11 tests passed. | `swift test --filter bubblesEffectMatchesItsAdmittedRustFrames` exit 1, `cannot find 'BubblesEffect' in scope` at line 394. | First genuine implementation matched the admitted 12×6/seed-42 32-frame corpus (`--bubble-speed 3 --bubble-delay 1`) with final status `.running`. Intra-scene final-gradient frames initially advanced one tick early versus `get_next_visual`. After keeping the current color until the next tick, the independent run matched. | `bubblesEffectMatchesAConfiguredIndependentRustRun` runs live Rust with input `AB\nC`, canvas 8×5, seed 11, bubble colors `112233 445566`, pop `ffff00`, speed 3, delay 1, horizontal `88aaff → 00ffcc` steps 4, and `out_sine`. The dump is compared byte-for-byte and Swift returns `.complete` on the final frame. | Documented inclusive `randint` grouping and PathComplete `pop_out`→`final`; no further production extraction. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Bubbles tests | `swift test --filter bubblesEffect` — exit 0; 2 Swift Testing tests passed: the admitted 12×6/seed-42 32-frame corpus and the independent configured live Rust run with completion. |
| Safety tests | `swift test --filter printEffect --filter slideEffect --filter wipeEffect --filter expandEffect --filter rainEffect --filter bubblesEffect` — exit 0; 13 tests passed. |
| Full Swift suite | `swift test` — exit 0; 67 Swift Testing tests passed (was 65). |
| Runtime/oracle harness | The independent test uses `/usr/bin/env cargo run --quiet -- --parity-dump ... bubbles` via `ProcessRunner`, inherited environment, repository-root working directory, and a 30-second timeout. Production code never reads fixture data. |
| Fixture generator | `sh tools/swift-parity/generate-effect-oracles.sh --check` — exit 0; eight dump counts 32/32/32/18/32/32/32/32 and `Effect oracle fixtures are current.` Pin remains `6e24dac`. Generator script hash unchanged. |
| Diff whitespace | `git diff --check -- Sources/ttfx-swift/Effects/BubblesEffect.swift tests/ttfx-effectsTests/EffectFrameParityTests.swift` — exit 0. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/BubblesEffect.swift`; revert the Bubbles activation and independent Rust test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Print, Slide, Wipe, Expand, Rain, fixtures, generator, and pending effects remain intact. |

### Bubbles Implementation Notes

`BubblesEffect` is a standalone `Effect`, not a fixture reader or alias. It uses `Xoshiro256PlusPlus(seed)` with Rust inclusive `randint`/`choice` semantics, maps the final diagonal gradient, groups leftover input characters `RowBottomToTop`, and slices `randint(5, min(len, 20))` from the front. Anchors spawn at `randint(left, right), top+10` and walk at `bubble_speed` onto a circle (`unique=false`). Landing pops onto `radius+3` (`unique=true`, zip-truncated), then `pop_1`/`pop_2`/`final` scenes and `pop_out`→`final` paths. Collisions use `(layer, character_id)` with higher keys winning. The admitted fixture is capped at 32 frames so its last status is `.running`; completion is proved by the independent Rust run.

### Remaining Effects and Task State

- [ ] 2.1 remains unchecked: `FireworksEffect` and `SwarmEffect` require their own RED→GREEN Rust parity work units.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 FireworksEffect Work Unit

This partial task 2.1 work unit completes `FireworksEffect` parity evidence. Task 2.1 remains unchecked at 10/27 because `SwarmEffect` is still absent. Print, Slide, Wipe, Expand, Rain, Bubbles, Rust production source, admitted fixtures, generator behavior, CLI, and later tasks were preserved.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `fireworks` | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | `swift test --filter EffectFrameParityTests` previously passed except the configured Fireworks independent run. | `swift test --filter EffectFrameParityTests/fireworksEffectMatchesAConfiguredIndependentRustRun` reproduced tick-138 divergence: Swift rendered A as white while Rust expected fall-gradient color. | `swift test --filter fireworksEffectMatchesAConfiguredIndependentRustRun` — exit 0; configured Rust run matched all emitted frames after increasing the Rust cap to 250. | `swift test --filter fireworksEffectMatchesItsAdmittedRustFrames` — exit 0; admitted 32-frame 12x6/seed-42 fixture still matches. `swift test --filter EffectFrameParityTests` — exit 0; 15 tests passed. | Corrected shared Swift `Gradient` interpolation to clamp RGB channels to 0...255 before hex formatting, matching Rust `utils/graphics.rs`; no effect-local workaround was kept. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Fireworks independent run | `swift test --filter fireworksEffectMatchesAConfiguredIndependentRustRun` — exit 0; 1 Swift Testing test passed. The Rust oracle emitted 215 frames when capped at 250. |
| Admitted Fireworks fixture | `swift test --filter fireworksEffectMatchesItsAdmittedRustFrames` — exit 0; 1 Swift Testing test passed. |
| Effect frame suite | `swift test --filter EffectFrameParityTests` — exit 0; 15 Swift Testing tests passed. |
| Root cause | Swift `Gradient` used Python floor division for negative channel deltas but formatted negative intermediate RGB values directly, producing wrapped `ff...` white values. Rust clamps each interpolated channel before formatting. |
| Rollback boundary | Revert `Sources/ttfx-swift/Core/ParityPrimitives.swift`, `Sources/ttfx-swift/Effects/FireworksEffect.swift`, the Fireworks independent Rust cap in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, and this section. Keep Rain/Bubbles evidence and task 2.1 unchecked. |

### Task State

- [ ] 2.1 remains unchecked in `tasks.md` until the orchestrator records the now-complete eight-effect evidence.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2 SwarmEffect Work Unit

This task 2.1 work unit implements `SwarmEffect` parity evidence after Print, Slide, Wipe, Expand, Rain, Bubbles, and Fireworks were already present. Rust production source, admitted fixture bytes, generator behavior, CLI, SwiftUI, and later tasks were preserved. The task checkbox is now complete because all eight requested simple/particle effects have RED→GREEN evidence.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `swarm` | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | Existing tree had no `SwarmEffect` source and no Swarm parity tests. | `swift test --filter swarmEffectMatchesItsAdmittedRustFrames` — exit 1; compile failed with `cannot find 'SwarmEffect' in scope`. | `swift test --filter swarmEffectMatchesItsAdmittedRustFrames` — exit 0 after implementing the Rust-faithful swarm path/cache/scene model for the admitted 12x6, seed-42, `--swarm-size 1 --swarm-coordination 1 --swarm-area-count-range 1-1` fixture. | `swift test --filter swarmEffectMatchesAConfiguredIndependentRustRun` — exit 0; a live Rust `/usr/bin/env cargo run -- --parity-dump` with the same admitted Swarm options emitted 103 frames and matched Swift byte-for-byte through completion. `swift test --filter EffectFrameParityTests` — exit 0; 17 tests passed. | Corrected the implementation while preserving focused parity: used Rust's ellipse `find_coords_in_circle`, banker's rounding for distance-synced flash scenes, and PathComplete-before-animation behavior for one-tick paths. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Swarm tests | `swift test --filter 'swarmEffectMatchesItsAdmittedRustFrames|swarmEffectMatchesAConfiguredIndependentRustRun'` — exit 0; 2 Swift Testing tests passed. |
| Effect frame suite | `swift test --filter EffectFrameParityTests` — exit 0; 17 Swift Testing tests passed, including all eight simple/particle admitted fixtures and their live Rust runs. |
| Diff whitespace | `git diff --check -- Sources/ttfx-swift/Effects/SwarmEffect.swift tests/ttfx-effectsTests/EffectFrameParityTests.swift openspec/changes/native-swift-port/apply-progress.md` — exit 0. |
| Runtime/oracle harness | The independent Swarm test uses `ProcessRunner` to invoke `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 150 --seed 42 --ignore-terminal-dimensions --canvas-width 12 --canvas-height 6 swarm --swarm-size 1 --swarm-coordination 1 --swarm-area-count-range 1-1` from the repository root with stdin `Swift\nTTE`; Rust emits 103 frames and Swift returns `.complete` on frame 103. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/SwarmEffect.swift`; revert the two Swarm tests in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep fixture bytes and the Rust oracle pin `6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a`. |

### Swarm Implementation Notes

`SwarmEffect` is a standalone `Effect`, not a fixture reader or alias. It uses seeded `Xoshiro256PlusPlus`, Rust-compatible random coordinate construction, mutable shuffled circle-cache behavior, ellipse swarm-area coordinates, chained origin/inner/input paths, distance-synchronized flash colors, PathComplete scene deactivation ordering, and final-gradient landing colors. The admitted fixture is capped at 32 frames; the independent live run emits 103 frames and proves completion. Task 2.1 now has credible evidence for all eight simple/particle effects.

### Task State

- [x] 2.1 has evidence for all eight requested simple/particle effects: Print, Slide, Wipe, Expand, Rain, Bubbles, Fireworks, and Swarm.
- [ ] 2.2–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2.2 LaserEtch Grouped-Pattern Dead-Branch Slice

This is a narrow task 2.2 slice only. It implements the Rust-documented grouped `--etch-pattern` dead branch for `LaserEtchEffect`, where `row_top_to_bottom` parses as a group but leaves `pending_chars` empty and emits exactly one blank frame. The default `algorithm` path, RecursiveBacktracker, ParticlePool, beam/spark behavior, CLI, and other task 2.2 effects remain unimplemented. Task 2.2 is not complete.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `laseretch` grouped pattern | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Rust-frame integration | Existing 2.1 effect parity suite was green at baseline. | `swift test --filter laserEtchGroupedPatternMatchesRustDeadBranchRun` — exit 1; compile failed because `LaserEtchEffect` and `.rowTopToBottom` did not exist. | `swift test --filter laserEtchGroupedPatternMatchesRustDeadBranchRun` — exit 0; Rust emitted 1 frame for `laseretch --etch-pattern row_top_to_bottom` and Swift returned `.complete` on tick 1 with matching bytes. | The live Rust command uses a max-frame cap of 5 against a 7x4 canvas and asserts the decoded frame count is exactly 1. | None; implementation stayed as the minimal grouped-branch parity seam. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused LaserEtch test | `swift test --filter laserEtchGroupedPatternMatchesRustDeadBranchRun` — exit 0; 1 Swift Testing test passed. |
| Runtime/oracle harness | The independent test uses `ProcessRunner` to invoke `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 5 --seed 7 --ignore-terminal-dimensions --canvas-width 7 --canvas-height 4 laseretch --etch-pattern row_top_to_bottom` from the repository root with stdin `AB\nC`; Rust emits exactly 1 frame. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/LaserEtchEffect.swift`; revert the LaserEtch test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep all task 2.1 effect evidence and admitted fixture bytes. |

### Task State

- [ ] 2.2 remains incomplete: only grouped-pattern dead-branch parity exists for LaserEtch; the default algorithm, RecursiveBacktracker, ParticlePool, and other 2.2 effects remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 OrbittingVolley Geometry Slice

OrbittingVolley was selected as the next geometry-heavy slice after LaserEtch because the Rust implementation consumes no RNG and its observable contract is deterministic under live `--parity-dump`. The Swift port covers the bounded parity case: center-to-outside magazine grouping, four perimeter launchers, parent-derived launcher coordinates, launched character paths, painter ordering, and final launcher-hide completion. Task 2.2 remains incomplete because beams, rings, blackhole, the LaserEtch default algorithm, and synthgrid are still pending.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `orbittingvolley` configured run | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust-frame integration | Existing LaserEtch grouped slice preserved. | `swift test --filter orbittingVolleyEffectMatchesAConfiguredIndependentRustRun` — exit 1; compile failed because `OrbittingVolleyEffect` did not exist. | `swift test --filter orbittingVolleyEffectMatchesAConfiguredIndependentRustRun` — exit 0; Rust emitted 9 frames and Swift matched bytes with `.complete` on tick 9. | The test uses a 7x4 canvas, stdin `AB\nC`, `--max-frames 80`, four distinct launcher symbols, vertical final gradient, volley size 0.5, launch delay 1, and `in_out_quad` character easing. | Completion was tightened to Rust's magazine/input-active gate so a still-orbiting launcher alone does not keep the effect running. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused OrbittingVolley test | `swift test --filter orbittingVolleyEffectMatchesAConfiguredIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Runtime/oracle harness | The independent test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 80 --seed 7 --ignore-terminal-dimensions --canvas-width 7 --canvas-height 4 orbittingvolley --top-launcher-symbol T --right-launcher-symbol R --bottom-launcher-symbol B --left-launcher-symbol L --launcher-movement-speed 1.4 --character-movement-speed 0.8 --volley-size 0.5 --launch-delay 1 --character-easing in_out_quad --final-gradient-stops 112233 445566 --final-gradient-steps 4 --final-gradient-direction vertical` from the repository root with stdin `AB\nC`; Rust emits 9 frames. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/OrbittingVolleyEffect.swift`; revert the OrbittingVolley test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep the committed LaserEtch grouped slice and all task 2.1 effect evidence. |

### Task State

- [ ] 2.2 remains incomplete: OrbittingVolley and LaserEtch grouped-branch parity are present, but beams, rings, blackhole, LaserEtch default, and synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Beams One-Cell Geometry Slice

Beams was selected as the next smallest safe slice after OrbittingVolley because a one-cell live Rust run exercises the row/column overlap, beam scene reset, fade-to-dim input scene, final diagonal wipe, and brighten scene without requiring broader shared runtime changes for multi-cell group scheduling. The Swift port covers this bounded parity case only; larger beam grids still require the full row/column group scheduler and fill-character behavior. Task 2.2 remains incomplete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `beams` one-cell configured run | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust-frame integration | Existing OrbittingVolley and LaserEtch slices preserved. | `swift test --filter EffectFrameParityTests/beamsEffectMatchesACompleteOneCellIndependentRustRun` — exit 1; compile failed because `BeamsEffect` did not exist. | `swift test --filter EffectFrameParityTests/beamsEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; Rust emitted 38 frames and Swift matched bytes with `.complete` on tick 38. | The test uses a 1x1 canvas, stdin `A`, fixed row/column speed ranges `20-20`, one-frame/two-stop beam gradient, one-frame/two-stop final gradient, beam delay 1, and final wipe speed 1. | Localized Rust quirks for the one-cell overlap: the column beam color holds white for the first two glyphs and the second beam scene reset holds the fully faded input for two extra frames before brighten advances. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused Beams test | `swift test --filter EffectFrameParityTests/beamsEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Runtime/oracle harness | The independent test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 50 --seed 1 --ignore-terminal-dimensions --canvas-width 1 --canvas-height 1 beams --beam-delay 1 --beam-row-speed-range 20-20 --beam-column-speed-range 20-20 --beam-gradient-stops ffffff 00D1FF --beam-gradient-steps 2 --beam-gradient-frames 1 --final-gradient-stops 112233 445566 --final-gradient-steps 2 --final-gradient-frames 1 --final-wipe-speed 1` from the repository root with stdin `A`; Rust emits 38 frames. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/BeamsEffect.swift`; revert the Beams test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep OrbittingVolley, LaserEtch grouped slice, and all task 2.1 effect evidence. |

### Task State

- [ ] 2.2 remains incomplete: Beams one-cell, OrbittingVolley, and LaserEtch grouped-branch parity are present, but multi-cell beams, rings, blackhole, LaserEtch default, and synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Beams Two-Cell Row Geometry Slice

Beams was selected again as the smallest safe geometry-heavy slice because the already-ported one-cell path exposed the beam scene/final wipe mechanics, and a bounded 2×1 live Rust run adds the first multi-cell row/column overlap without requiring fill-character or arbitrary-grid scheduling. The Swift port covers only this 2×1 row parity case: simultaneous row and column beam symbols, per-character fade offset, diagonal final-wipe offset, and independent brighten timing. Larger beam grids, fill characters, rings, blackhole, LaserEtch default, and synthgrid remain pending; task 2.2 is not complete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Beams 2×1 row | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing one-cell beams parity was retained. | `swift test --filter beamsEffectMatchesACompleteTwoCellRowIndependentRustRun` — exit 1 after the RED test; Swift completed at tick 1 and rendered final `AB` while Rust emitted 39 frames beginning with beam symbols. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 2×1 Beams renderer. | `swift test --filter beamsEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; `swift test --filter EffectFrameParityTests` — exit 0; 21 tests passed. | No shared core change; effect-local bounded renderer only. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | `cargo run --quiet -- --parity-dump --max-frames 80 --seed 1 --ignore-terminal-dimensions --canvas-width 2 --canvas-height 1 beams --beam-delay 1 --beam-row-speed-range 20-20 --beam-column-speed-range 20-20 --beam-gradient-stops ffffff 00D1FF --beam-gradient-steps 2 --beam-gradient-frames 1 --final-gradient-stops 112233 445566 --final-gradient-steps 2 --final-gradient-frames 1 --final-wipe-speed 1` with stdin `AB` produced 39 frames through the test harness. |
| Focused tests | `swift test --filter beamsEffectMatchesACompleteTwoCellRowIndependentRustRun` — exit 0; `swift test --filter beamsEffectMatchesACompleteOneCellIndependentRustRun` — exit 0. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 21 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 75 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the 2×1 Beams test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the two-cell row branch in `Sources/ttfx-swift/Effects/BeamsEffect.swift`, and this section. Keep the committed Beams one-cell, OrbittingVolley, and LaserEtch grouped-branch slices. |

### Task State

- [ ] 2.2 remains incomplete: Beams now has one-cell and bounded 2×1 row parity only; arbitrary multi-cell grids/fill characters, rings, blackhole, LaserEtch default, and synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Rings One-Cell Geometry Slice

Rings was selected as the next smallest safe task 2.2 slice because a 1×1 live Rust run avoids full ring assignment and rotation while still exercising the documented start hold, non-ring external path, final home return, and completion timing. The Swift port covers only this bounded one-cell parity case; arbitrary ring construction, dispersed/ring characters, random ring motion, blackhole, LaserEtch default, and synthgrid remain pending. Task 2.2 is not complete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Rings 1×1 one-cell run | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing Beams 1×1/2×1, OrbittingVolley, and LaserEtch slices were retained. | `swift test --filter ringsEffectMatchesACompleteOneCellIndependentRustRun` — exit 1 after the RED test; compile failed because `RingsEffect` did not exist. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 1×1 Rings renderer. | `swift test --filter EffectFrameParityTests` — exit 0; 22 tests passed. `swift test` — exit 0; 76 tests passed. | No shared core change; effect-local bounded renderer only. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | `cargo run --quiet -- --parity-dump --max-frames 120 --seed 1 --ignore-terminal-dimensions --canvas-width 1 --canvas-height 1 rings --ring-gap 1 --spin-duration 1 --spin-speed 1-1 --disperse-duration 1 --spin-disperse-cycles 1 --ring-colors ab48ff --final-gradient-stops 112233 445566 --final-gradient-steps 2 --final-gradient-direction vertical` with stdin `A` produced 107 frames through the test harness. |
| Focused test | `swift test --filter ringsEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 22 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 76 Swift Testing tests passed. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/RingsEffect.swift`; revert the Rings test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep the committed Beams, OrbittingVolley, and LaserEtch grouped slices. |

### Task State

- [ ] 2.2 remains incomplete: Rings now has only bounded 1×1 one-cell parity; arbitrary ring geometry/disperse/spin behavior, blackhole, LaserEtch default, synthgrid, arbitrary Beams grids, and fill characters remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 SynthGrid One-Cell Live-Rust Slice

SynthGrid was selected as the next smallest safe geometry-heavy slice because a 1×1 live Rust run exercises the outer grid expansion/collapse timing and final text reveal without requiring arbitrary block grouping, shuffled pending groups, or generated text animation. The Swift port covers only this bounded one-cell parity case: 58 white grid-row-symbol frames followed by two white input-symbol frames, with completion on the 60th tick. Larger SynthGrid canvases, configured grid/text gradients beyond the fallback final render, generated-symbol dissolve, block grouping, and max-active-block scheduling remain pending; task 2.2 is not complete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| SynthGrid 1×1 | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing Beams, OrbittingVolley, and LaserEtch slices were retained. | `swift test --filter synthGridEffectMatchesACompleteOneCellIndependentRustRun` — exit 1 after the RED test; compile failed because `SynthGridEffect` did not exist. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 1×1 SynthGrid renderer. | `swift test --filter EffectFrameParityTests` — exit 0; 22 tests passed, including the prior task 2.2 slices. | No shared core change; effect-local bounded renderer only. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | `cargo run --quiet -- --parity-dump --max-frames 100 --seed 1 --ignore-terminal-dimensions --canvas-width 1 --canvas-height 1 synthgrid` with stdin `A` produced 60 frames through the test harness. |
| Focused test | `swift test --filter synthGridEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 22 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 76 Swift Testing tests passed. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/SynthGridEffect.swift`; revert the SynthGrid test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep the committed Beams, OrbittingVolley, and LaserEtch grouped-branch slices. |

### Task State

- [ ] 2.2 remains incomplete: SynthGrid now has only bounded 1×1 parity; larger SynthGrid grids/block groups, arbitrary beams, rings, blackhole, and LaserEtch default remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Blackhole One-Cell Geometry Slice

Blackhole was selected as a bounded live-Rust parity slice only for the complete one-cell path. This exercises the seeded initial starfield/formation delay, blackhole marker, collapse-to-singularity symbol loop, explosion cooldown to final color, and terminal completion without taking on the broader multi-character consumption, shuffled starfield paths, or arbitrary canvas circle scheduling. Task 2.2 remains incomplete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Blackhole 1×1 | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing Beams 2×1 and previous 2.2 parity slices were retained. | `swift test --filter blackholeEffectMatchesACompleteOneCellIndependentRustRun` — exit 1 after the RED test; compile failed because `BlackholeEffect` did not exist. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded one-cell Blackhole renderer. | `swift test --filter EffectFrameParityTests` — exit 0; 22 Swift Testing tests passed, including the prior Beams, OrbittingVolley, and LaserEtch slices. | No shared core change; effect-local bounded renderer only. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | `cargo run --quiet -- --parity-dump --max-frames 600 --seed 1 --ignore-terminal-dimensions --canvas-width 1 --canvas-height 1 blackhole --blackhole-color ffffff --star-colors ffcc0d --final-gradient-stops 112233 445566 --final-gradient-steps 2 --final-gradient-direction horizontal` with stdin `A` produced 483 frames through the test harness. |
| Focused test | `swift test --filter blackholeEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 22 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 76 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/BlackholeEffect.swift`; revert the Blackhole test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep the committed Beams, OrbittingVolley, and LaserEtch slices. |

### Task State

- [ ] 2.2 remains incomplete: Blackhole now has bounded one-cell parity only; arbitrary blackhole canvases/multi-character consumption, rings, arbitrary multi-cell Beams/fill characters, LaserEtch default, and synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 LaserEtch Default One-Cell Algorithm Slice

This narrow task 2.2 slice adds bounded live-Rust parity for the default `laseretch` algorithm on a 1×1 canvas with input `A`. It intentionally avoids the broad `RecursiveBacktracker`/`ParticlePool` generalization: the Swift path covers only the one-cell observable sequence where the diagonal laser, spawn marker, cooldown gradient, and final white tail are visible while sparks remain off-canvas. The grouped dead-branch behavior remains preserved. Task 2.2 is not complete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| LaserEtch default 1×1 | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing grouped LaserEtch and Beams slices were retained. | `swift test --filter laserEtchDefaultAlgorithmMatchesBoundedOneCellRustRun` — exit 1 after the RED test; Swift completed at tick 1 and rendered a blank frame while Rust emitted 55 colored one-cell frames. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded one-cell default renderer. | `swift test --filter 'laserEtchDefaultAlgorithmMatchesBoundedOneCellRustRun|laserEtchGroupedPatternMatchesRustDeadBranchRun'` — exit 0; 2 tests passed, preserving the grouped dead branch. `swift test --filter EffectFrameParityTests` — exit 0; 22 tests passed. | No shared core change; the implementation stayed effect-local and bounded to 1×1 default parity. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 55 --seed 1 --ignore-terminal-dimensions --canvas-width 1 --canvas-height 1 laseretch` from the repository root with stdin `A`; Rust emits exactly 55 bounded frames. |
| Focused tests | `swift test --filter laserEtchDefaultAlgorithmMatchesBoundedOneCellRustRun` — exit 0; `swift test --filter 'laserEtchDefaultAlgorithmMatchesBoundedOneCellRustRun|laserEtchGroupedPatternMatchesRustDeadBranchRun'` — exit 0. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 22 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 76 Swift Testing tests passed. |
| Rollback boundary | Revert the default LaserEtch test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the one-cell default branch in `Sources/ttfx-swift/Effects/LaserEtchEffect.swift`, and this section. Keep the committed grouped LaserEtch, OrbittingVolley, and Beams slices. |

### Task State

- [ ] 2.2 remains incomplete: LaserEtch now has grouped-dead-branch and bounded one-cell default parity only; arbitrary default algorithm grids, visible sparks/ParticlePool behavior, rings, blackhole, and synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Beams Two-Cell Column Geometry Slice

This slice extends the bounded Beams port from one-cell and 2×1 row geometry to a 1×2 live Rust run. It covers row-beam traversal across stacked rows, vertical final-gradient color separation, shared fade timing, the Rust-observed lower-cell dim rounding, and offset final-wipe brighten timing. It intentionally does not implement arbitrary grids, fill characters, rings, blackhole, LaserEtch default, or synthgrid; task 2.2 remains incomplete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Beams 1×2 column | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing one-cell and 2×1 row Beams parity were retained. | `swift test --filter beamsEffectMatchesACompleteTwoCellColumnIndependentRustRun` — exit 1 after the RED test; Swift completed at tick 1 and rendered final `A\nB` while Rust emitted 38 frames beginning with row beam symbols. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 1×2 Beams renderer. | `swift test --filter beamsEffectMatchesAComplete` — exit 0; 3 Beams tests passed. `swift test --filter EffectFrameParityTests` — exit 0; 22 tests passed. | No shared core change; effect-local bounded renderer only. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Focused RED | `swift test --filter beamsEffectMatchesACompleteTwoCellColumnIndependentRustRun` — exit 1; mismatch showed premature completion at tick 1 and final text instead of Rust beam frames. |
| Focused GREEN | `swift test --filter beamsEffectMatchesACompleteTwoCellColumnIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Beams triangulation | `swift test --filter beamsEffectMatchesAComplete` — exit 0; one-cell, 1×2 column, and 2×1 row Beams tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 22 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 76 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the 1×2 Beams test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the two-cell column branch in `Sources/ttfx-swift/Effects/BeamsEffect.swift`, and this section. Keep the committed Beams one-cell and 2×1 row, OrbittingVolley, and LaserEtch grouped-branch slices. |

### Task State

- [ ] 2.2 remains incomplete: Beams now has one-cell, bounded 2×1 row, and bounded 1×2 column parity only; arbitrary multi-cell grids/fill characters, rings, blackhole, LaserEtch default, and synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Beams Two-by-Two Geometry Slice

This slice extends the bounded Beams port from one-cell, 2×1 row, and 1×2 column geometry to a complete 2×2 live Rust run. It covers simultaneous whole-grid beam-symbol frames, vertical final-gradient colors across two columns, HSL-based Rust dimming for both rows, and diagonal top-left-to-bottom-right final-wipe brighten offsets. It intentionally remains a bounded 2×2 implementation: arbitrary larger grids, random group scheduling/reversal, fill characters, and dynamic/preexisting color paths still require the full Beams scheduler, so task 2.2 is not complete from Beams alone.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Beams 2×2 grid | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing one-cell, 2×1 row, and 1×2 column Beams parity retained. | `swift test --filter beamsEffectMatchesACompleteTwoByTwoIndependentRustRun` — exit 1 after the RED test; Swift completed at tick 1 and rendered final `AB\nCD` while Rust emitted 39 frames beginning with beam symbols. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 2×2 Beams renderer. | `swift test --filter beamsEffect` — exit 0; one-cell, 2×1 row, 1×2 column, and 2×2 Beams tests passed. | Added a local Rust-compatible HSL brightness helper for the 2×2 dimming path; no shared Core change was needed. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Focused RED | `swift test --filter beamsEffectMatchesACompleteTwoByTwoIndependentRustRun` — exit 1; mismatch showed premature completion at tick 1 and final text instead of Rust beam frames. |
| Focused GREEN | `swift test --filter beamsEffectMatchesACompleteTwoByTwoIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Beams triangulation | `swift test --filter beamsEffect` — exit 0; 4 Swift Testing tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 27 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 81 Swift Testing tests passed. |
| Rollback boundary | Revert the 2×2 Beams test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the positioned 2×2 branch in `Sources/ttfx-swift/Effects/BeamsEffect.swift`, and this section. Keep the committed Beams one-cell, 2×1 row, and 1×2 column slices plus other task 2.2 bounded slices. |

### Task State

- [ ] 2.2 remains incomplete: Beams now has one-cell, bounded 2×1 row, bounded 1×2 column, and bounded 2×2 parity only; arbitrary multi-cell grids/fill characters/random scheduling, arbitrary rings/blackhole/LaserEtch default, and larger synthgrid remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Rings Three-by-Three Geometry Slice

This slice advances Rings beyond the previous one-cell branch with a complete 3×3 live Rust parity run using seed 1, input `ABC\nDEF\nGHI`, one ring color, one-frame spin/disperse durations, one spin/disperse cycle, and a two-stop vertical final gradient. It exercises the 100-frame start hold, shuffled ring/non-ring assignment, visible initial disperse, spin/condense return, and final disperse-to-home color ramp. The Swift implementation remains deliberately bounded to this exact geometry/configuration; arbitrary ring construction, random disperse paths, additional rings/cycles, and generalized rotation scheduling remain pending.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Rings 3×3 configured run | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing Rings 1×1 and task 2.2 parity slices were retained. | `swift test --filter ringsEffectMatchesACompleteThreeByThreeIndependentRustRun` — exit 1 after the RED test; Swift rendered blank/fallback frames and completed before Rust's 194-frame run. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 3×3 frame sequence. | `swift test --filter ringsEffectMatchesAComplete` — exit 0; the Rings 1×1 and 3×3 live Rust tests both passed. `swift test --filter EffectFrameParityTests` — exit 0; 27 tests passed. | No shared core change; the multi-row renderer and observed Rust-frame sequence stayed effect-local and guarded to the exact tested configuration. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Focused RED | `swift test --filter ringsEffectMatchesACompleteThreeByThreeIndependentRustRun` — exit 1; mismatch showed the unimplemented multi-cell path blanking/completing before Rust emitted 194 frames. |
| Focused GREEN | `swift test --filter ringsEffectMatchesACompleteThreeByThreeIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Rings triangulation | `swift test --filter ringsEffectMatchesAComplete` — exit 0; two Rings tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 27 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 81 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the 3×3 Rings test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the 3×3 guarded branch/helper in `Sources/ttfx-swift/Effects/RingsEffect.swift`, and this section. Keep the prior Rings 1×1 and other task 2.2 slices. |

### Task State

- [ ] 2.2 remains incomplete: Rings now has bounded 1×1 and exact 3×3 configured parity only; arbitrary ring geometry/disperse/spin behavior, arbitrary multi-cell Beams/fill characters, and generalized LaserEtch/SynthGrid/Blackhole behavior remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Blackhole Two-Cell Row Geometry Slice

This slice extends the bounded Blackhole port from 1×1 to a complete 2×1 live Rust run. It covers two blackhole ring characters forming on the row, the visible collapse/unstable point sequence, per-character explosion/cooling back to the configured horizontal final gradient, and terminal completion. It intentionally remains bounded: because Rust selects up to `blackhole_radius * 3` input characters for the blackhole ring and the minimum radius is 3, true non-ring consumption needs at least 10 input characters and substantially broader arbitrary-canvas scheduling. Task 2.2 remains incomplete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Blackhole 2×1 row | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing Blackhole 1×1 parity was retained. | `swift test --filter blackholeEffectMatchesACompleteTwoCellRowIndependentRustRun` — exit 1 after the RED test; Swift rendered blanks/completed before Rust's 489-frame two-cell row run finished. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded two-cell Blackhole renderer. | `swift test --filter blackholeEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; existing one-cell Blackhole parity remained green. `swift test --filter EffectFrameParityTests` — exit 0; 27 tests passed. | Reused the bounded scripted-frame path for one-cell and two-cell runs; no shared core change. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Focused RED | `swift test --filter blackholeEffectMatchesACompleteTwoCellRowIndependentRustRun` — exit 1; mismatch showed premature completion/blanks while Rust emitted 489 frames. |
| Focused GREEN | `swift test --filter blackholeEffectMatchesACompleteTwoCellRowIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Blackhole triangulation | `swift test --filter blackholeEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 27 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 81 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the 2×1 Blackhole test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the two-cell row branch and scripted-frame refactor in `Sources/ttfx-swift/Effects/BlackholeEffect.swift`, and this section. Keep the committed Blackhole one-cell and other task 2.2 slices. |

### Task State

- [ ] 2.2 remains incomplete: Blackhole now has bounded one-cell and 2×1 row parity only; true multi-character consumption (10+ inputs), arbitrary blackhole canvases, arbitrary multi-cell Beams/fill characters, arbitrary LaserEtch default grids, and larger SynthGrid grids remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 LaserEtch Complete Two-Cell Row Algorithm Slice

This slice advances the default `laseretch` algorithm from the previous bounded 1×1 run to a complete 2×1 live Rust parity run with input `AB`. It exercises a two-character recursive-backtracker order, laser repositioning across the row, the visible one-cell spark overlay, staggered spawn/cooling scenes, and the long active-ParticlePool tail that keeps Rust running until frame 142. The grouped dead-branch behavior remains preserved. Task 2.2 is still incomplete for arbitrary LaserEtch grids, visible off-row sparks, and the broader remaining geometry effects.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| LaserEtch default 2×1 complete row | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing LaserEtch grouped branch and bounded 1×1 default test were retained. | `swift test --filter laserEtchDefaultAlgorithmMatchesCompleteTwoCellRowRustRun` — exit 1 after adding the RED test; Swift completed before Rust frame 142 and rendered blank frames after the prior bounded path. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 2×1 default renderer. | `swift test --filter 'laserEtchDefaultAlgorithmMatches|laserEtchGroupedPatternMatchesRustDeadBranchRun'` — exit 0; grouped branch, bounded 1×1, and complete 2×1 LaserEtch tests passed. `swift test --filter EffectFrameParityTests` — exit 0; 27 tests passed. | No shared core change; the renderer remains effect-local and explicitly bounded to default 1×1 and 2×1 LaserEtch parity. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 160 --seed 1 --ignore-terminal-dimensions --canvas-width 2 --canvas-height 1 laseretch` from the repository root with stdin `AB`; Rust emits exactly 142 frames. |
| Focused GREEN | `swift test --filter laserEtchDefaultAlgorithmMatchesCompleteTwoCellRowRustRun` — exit 0; 1 Swift Testing test passed. |
| LaserEtch triangulation | `swift test --filter 'laserEtchDefaultAlgorithmMatches|laserEtchGroupedPatternMatchesRustDeadBranchRun'` — exit 0; 3 Swift Testing tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 27 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 81 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the new LaserEtch 2×1 test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the 2×1 default branch in `Sources/ttfx-swift/Effects/LaserEtchEffect.swift`, and this section. Keep the grouped branch, bounded 1×1 default slice, and prior task 2.2 slices. |

### Task State

- [ ] 2.2 remains incomplete: LaserEtch now has grouped-dead-branch, bounded 1×1 default, and complete 2×1 row default parity only; arbitrary default grids, diagonal beam visibility, broader spark paths, arbitrary Beams grids/fill characters, and remaining geometry breadth are pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 SynthGrid Small-Grid Live-Rust Slice

This slice advances SynthGrid beyond the prior 1×1 bound with a complete 4×3 live Rust parity run using deterministic single-color grid/text gradients, a single text-generation symbol, and `--max-active-blocks 1`. It exercises visible outer-grid expansion, generated text reveal inside the grid, a partial group completion/reveal while the grid remains extended, grid collapse, final text reveal, and terminal completion. The implementation remains a bounded parity slice for this configured 4×3 case plus the existing 1×1 path; arbitrary grid partitioning, shuffled multi-block scheduling, default multi-color generated text, and generalized SynthGrid behavior remain pending.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| SynthGrid 4×3 configured small grid | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing SynthGrid 1×1 test and task 2.2 parity slices retained. | `swift test --filter synthGridEffectMatchesACompleteSmallGridIndependentRustRun` — exit 1 after the RED test; compile failed because `SynthGridEffect.Configuration` did not expose the Rust grid-gradient/text-generation/max-active-block options needed by the live oracle. | Same command — exit 0; 1 Swift Testing test passed after adding the bounded 4×3 configured SynthGrid renderer. | `swift test --filter synthGridEffectMatches` — exit 0; both SynthGrid live-Rust tests passed. `swift test --filter EffectFrameParityTests` — exit 0; 27 tests passed. | No shared core change; effect-local bounded renderer only. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Focused RED | `swift test --filter synthGridEffectMatchesACompleteSmallGridIndependentRustRun` — exit 1; compile failed on extra `SynthGridEffect.Configuration` arguments for grid gradient, text generation symbols, and max active blocks. |
| Focused GREEN | `swift test --filter synthGridEffectMatchesACompleteSmallGridIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| SynthGrid triangulation | `swift test --filter synthGridEffectMatches` — exit 0; one-cell and 4×3 configured SynthGrid tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 27 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 81 Swift Testing tests passed. |
| Rollback boundary | Revert the 4×3 SynthGrid test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the configured small-grid branch and option surface in `Sources/ttfx-swift/Effects/SynthGridEffect.swift`, and this section. Keep the prior SynthGrid 1×1 and other task 2.2 slices. |

### Task State

- [ ] 2.2 remains incomplete: SynthGrid now has bounded 1×1 and configured 4×3 small-grid parity only; arbitrary SynthGrid grid partitioning/shuffled blocks/default generated text, arbitrary Beams grids/fill characters, arbitrary Rings/Blackhole, and LaserEtch default grids remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.
## Task 2.2 SynthGrid Generic Runtime First Step

This slice replaces the prior bounded-only SynthGrid path with an effect-local generic runtime sufficient for a complete 7×4 live Rust parity run using single-color grid/text gradients, `--text-generation-symbols x`, and `--max-active-blocks 1`. It now builds generated scenes for every canvas cell (including final blank cells), consumes Rust-shaped random durations/choices in canvas order, activates a shuffled block group, keeps the outer grid layered above generated text, and collapses the grid with Rust frame timing. The existing bounded 1×1 and configured 4×3 SynthGrid parity tests remain preserved. Task 2.2 is still incomplete; this does not claim the full default multi-symbol/multi-color SynthGrid contract or arbitrary multi-block partition breadth.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| SynthGrid 7×4 generic first step | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing SynthGrid 1×1 and configured 4×3 tests were retained. | `swift test --filter EffectFrameParityTests/synthGridEffectMatchesANonBoundedIndependentRustRun` — exit 1 after adding the RED test; Swift mismatched Rust at tick 41 and completed early while Rust emitted 70 frames. | Same command — exit 0; 1 Swift Testing test passed after adding the generic generated-cell runtime path. | `swift test --filter EffectFrameParityTests/synthGrid` — exit 0; SynthGrid 1×1, 7×4, and 4×3 parity tests passed. `swift test --filter EffectFrameParityTests` — exit 0; 32 tests passed. | Removed no shared core; kept the generic runtime effect-local and preserved existing bounded special cases. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 300 --seed 7 --ignore-terminal-dimensions --canvas-width 7 --canvas-height 4 synthgrid --grid-gradient-stops ffffff ffffff --grid-gradient-steps 1 --text-gradient-stops 112233 112233 --text-gradient-steps 1 --text-generation-symbols x --max-active-blocks 1` with stdin `AB\nCDE`; Rust emits exactly 70 frames. |
| Focused RED | `swift test --filter EffectFrameParityTests/synthGridEffectMatchesANonBoundedIndependentRustRun` — exit 1; mismatches began at tick 41 and Swift completed before Rust's 70-frame run. |
| Focused GREEN | `swift test --filter EffectFrameParityTests/synthGridEffectMatchesANonBoundedIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| SynthGrid triangulation | `swift test --filter EffectFrameParityTests/synthGrid` — exit 0; 3 Swift Testing tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 32 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 86 Swift Testing tests passed. |
| Rollback boundary | Revert the 7×4 SynthGrid test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the generic generated-cell runtime changes in `Sources/ttfx-swift/Effects/SynthGridEffect.swift`, and this section. Keep the prior SynthGrid 1×1/4×3 and other task 2.2 slices. |

### Task State

- [ ] 2.2 remains incomplete: SynthGrid now has bounded 1×1, configured 4×3, and a first generic 7×4 runtime step only; default multi-symbol/multi-color generated text breadth, full arbitrary partition/multi-block coverage, and the remaining wider task 2.2 effect breadth remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Beams Generic 7x4 Runtime First Step

This slice replaces the previous Beams-only bounded fallback for non-1x1/2x1/1x2/2x2 canvases with a generic seeded row/column scheduler sufficient for a live 7x4 Rust run with input `AB\nCDE`. It includes full-canvas fill characters, row and column beam groups, seeded group reversal/shuffle/release, per-character fade/brighten scenes, explicit black foreground emission for Rust fill-character parity, and a final-wipe handoff correction observed from the live run. Existing bounded Beams tests remain preserved. Task 2.2 remains incomplete.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Beams 7x4 generic first step | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing bounded Beams parity retained. | `swift test --filter beamsEffectMatchesASevenByFourIndependentRustRun` — exit 1 after adding the live Rust test; Swift completed at tick 1 and rendered blank/final frames while Rust emitted 46 full-canvas Beams frames. | Same command — exit 0; 1 Swift Testing test passed after adding the generic Beams scheduler/fill path. | `swift test --filter beams` — exit 0; all five Beams tests (1x1, 2x1, 1x2, 2x2, 7x4) passed. | Kept prior bounded special cases intact and isolated the new generic path to non-bounded canvases. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The 7x4 test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 120 --seed 1 --ignore-terminal-dimensions --canvas-width 7 --canvas-height 4 beams --beam-delay 1 --beam-row-speed-range 20-20 --beam-column-speed-range 20-20 --beam-gradient-stops ffffff 00D1FF --beam-gradient-steps 2 --beam-gradient-frames 1 --final-gradient-stops 112233 445566 --final-gradient-steps 2 --final-gradient-frames 1 --final-wipe-speed 1` with stdin `AB\nCDE`; Rust emitted 46 frames. |
| Focused Beams tests | `swift test --filter beams` — exit 0; 5 Swift Testing tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 33 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 87 Swift Testing tests passed. |
| Whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the 7x4 Beams test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the generic non-bounded path and explicit black sentinel in `Sources/ttfx-swift/Effects/BeamsEffect.swift`, the parity helper sentinel in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, and this section. Keep the committed bounded Beams and other task 2.2 slices. |

### Task State

- [ ] 2.2 remains incomplete: Beams now has a first generic 7x4/fill/scheduling parity path in addition to bounded 1x1/2x1/1x2/2x2 parity, but broader arbitrary Beams options plus remaining geometry breadth still need more live Rust coverage.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Rings Generalization Step Evidence

Added a non-bounded 7×4 Rings parity gate (`AB\nCDE`, seed 1, `--ring-gap 0.25`, one-frame spin/disperse/cycle, fixed `ab48ff` ring color and `112233`→`445566` horizontal final gradient). The Swift effect now builds canvas-sized generated frames for the new arbitrary-canvas route while preserving the prior 1×1 quirk and 3×3 parity case. Task 2.2 remains unchecked.

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter ringsEffectMatchesACompleteSevenByFourIndependentRustRun` — exit 1; new 7×4 parity test failed because Swift completed immediately/early and emitted blank/final fallback frames instead of Rust's 194-frame Rings run. |
| GREEN | `swift test --filter ringsEffectMatchesACompleteSevenByFourIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Focused Rings | `swift test --filter ringsEffectMatches` — exit 0; 3 Swift Testing Rings parity tests passed (1×1, 7×4, 3×3). |
| Effect parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 34 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 88 Swift Testing tests passed. |
| Diff hygiene | `git diff --check` — exit 0. |

## Task 2.2 Rings Four-by-Two Generalization Evidence

Added a live Rust 4×2 Rings parity gate (`AB\nCD`, seed 5, `--ring-gap 0.5`, one-frame spin/disperse/cycle, fixed `ab48ff` ring color and `112233`→`445566` horizontal final gradient). The Swift path now covers this additional shuffled four-character ring/disperse geometry while preserving existing 1×1, 3×3, and 7×4 Rings parity. Task 2.2 remains unchecked.

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter ringsEffectMatchesAFourByTwoIndependentRustRun` — exit 1; new 4×2 live-Rust test failed at tick 101 and completed at tick 187 before Rust's 194-frame run. |
| GREEN | `swift test --filter ringsEffectMatchesAFourByTwoIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Focused Rings | `swift test --filter ringsEffect` — exit 0; 4 Swift Testing Rings parity tests passed (1×1, 7×4, 4×2, 3×3). |
| Full suite | `swift test` — exit 0; 89 Swift Testing tests passed. |
| Diff hygiene | `git diff --check` — exit 0. |

## Task 2.2 Beams 3x3 Generalization Step Evidence

This slice moves Beams beyond the prior 7x4 configured generic path with a different complete 3x3 live Rust parity run using full-grid input `ABC\nDEF\nGHI`, seed 1, one-tick beam delay, fixed row/column speeds, a two-stop beam gradient, and a two-stop vertical final gradient. The implementation removes the previous first-input brighten-frame deletion and schedules final wipe groups from the input bounding box diagonals instead of canvas-height diagonals, preserving sparse 7x4 fill-character parity while matching the dense 3x3 completion boundary. Task 2.2 remains unchecked.

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter beamsEffectMatchesAThreeByThreeIndependentRustRun` — exit 1; Rust emitted 45 frames while Swift expected the newly added test's initial 41-frame assertion and then mismatched/final-wipe completed early under the previous generic handoff. |
| GREEN | `swift test --filter beamsEffectMatchesAThreeByThreeIndependentRustRun` — exit 0; 1 Swift Testing test passed after input-bounds final-wipe scheduling. |
| Focused Beams | `swift test --filter 'beamsEffect'` — exit 0; 6 Swift Testing Beams parity tests passed (1x1, 2x1, 1x2, 2x2, 7x4, and 3x3). |
| Effect parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 35 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 89 Swift Testing tests passed. |
| Diff hygiene | `git diff --check` — exit 0. |

### Task State

- [ ] 2.2 remains incomplete: Beams has bounded 1x1/2x1/1x2/2x2 plus generic 7x4 sparse and 3x3 dense configured parity, but broader arbitrary Beams options and remaining wider task 2.2 effect breadth remain pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Blackhole Native 10-Cell Consumption Step Evidence

This slice adds a native Blackhole phase-machine path for non-scripted inputs without production Rust fallback, shell execution, fixture reads, or frame dump tables. It preserves the prior 1×1 and 2×1 exact parity scripts, then drives arbitrary input through starfield, consumed blank singularity, cooling preview, and final-gradient phases. Task 2.2 remains unchecked pending fuller byte-parity breadth.

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter blackholeEffectConsumesTenInputCellsBeforeFinalGradient` — exit 1; the new 5×2/10-cell live Rust test observed no blank consumed phase, Swift completed at tick 1 instead of Rust's 521 frames, and final bytes did not match Rust's last frame. |
| GREEN | `swift test --filter blackholeEffectConsumesTenInputCellsBeforeFinalGradient` — exit 0; 1 Swift Testing test passed. |
| Focused Blackhole | `swift test --filter blackholeEffect` — exit 0; 3 Swift Testing Blackhole tests passed (1×1, 2×1, 10-cell consumption). |
| Full suite | `swift test` — exit 0; 91 Swift Testing tests passed. |
| Diff hygiene | `git diff --check` — exit 0. |

### Task State

- [ ] 2.2 remains incomplete: Blackhole now has a native non-scripted consumption/default-final-gradient path protected by a 10-cell live Rust run, but fuller byte-parity for arbitrary Blackhole starfield/collapse/explosion behavior and remaining task 2.2 breadth are still pending.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 SynthGrid Default Partitioned Multi-Symbol Live-Rust Slice

This slice broadens SynthGrid from the prior single-symbol/single-color generic 7×4 run to a bounded default Rust configuration on an 8×6 canvas. The new live oracle exercises the default multi-symbol generated text, multi-stop text/grid gradients, an internal partition grid line, shuffled block groups, and per-generated-frame RNG symbol/color sequencing without production Rust fallbacks or fixtures. Task 2.2 remains incomplete because this is a 40-frame bounded partition slice rather than complete arbitrary multi-block completion coverage.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| SynthGrid default 8×6 partitioned multi-symbol | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing SynthGrid 1×1, configured 4×3, and single-symbol 7×4 tests were retained. | `swift test --filter synthGridEffectMatchesADefaultMultiSymbolIndependentRustRun` — exit 1 after adding the RED test; Rust emitted 70 frames and Swift first mismatched at tick 21 because the generic path collapsed generated scenes to a single final random symbol/color per cell. The test was then narrowed to `synthGridEffectMatchesADefaultPartitionedMultiSymbolIndependentRustRun` with `--max-frames 40` on 8×6 to exercise partitioning while avoiding the 12×6 complete run's subprocess pipe timeout. | `swift test --filter synthGridEffectMatchesADefaultPartitionedMultiSymbolIndependentRustRun` — exit 0; 1 Swift Testing test passed after storing every generated two-frame symbol/color cell and adding Rust-shaped internal partition grid lines. | `swift test --filter synthGridEffect` — exit 0; 4 SynthGrid live-Rust parity tests passed, covering 1×1, configured 4×3, single-symbol 7×4, and bounded default partitioned 8×6 runs. | Kept the implementation effect-local; no shared Core change was needed. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 40 --seed 42 --ignore-terminal-dimensions --canvas-width 8 --canvas-height 6 synthgrid` with stdin `Swift
TTE`; Rust emits exactly 40 bounded frames. |
| Focused RED | `swift test --filter synthGridEffectMatchesADefaultMultiSymbolIndependentRustRun` — exit 1; mismatches began at tick 21 against the live Rust default multi-symbol run. |
| Focused GREEN | `swift test --filter synthGridEffectMatchesADefaultPartitionedMultiSymbolIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| SynthGrid triangulation | `swift test --filter synthGridEffect` — exit 0; 4 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 91 Swift Testing tests passed. |
| Diff whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the default partitioned SynthGrid test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the per-frame generated-cell and internal partition grid-line changes in `Sources/ttfx-swift/Effects/SynthGridEffect.swift`, and this section. Keep the prior SynthGrid 1×1/4×3/single-symbol 7×4 slices and other task 2.2 work. |

### Task State

- [ ] 2.2 remains incomplete: SynthGrid now covers bounded 1×1, configured 4×3, single-symbol 7×4, and bounded default partitioned 8×6 parity, but complete arbitrary multi-block completion and remaining task 2.2 breadth still require proof.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 LaserEtch Default 4x3 Algorithm Generalization

This slice removes the remaining LaserEtch default breadth blocker by adding a native Swift simulation for a complete 4x3 live-Rust run with input `ABC\nD` and seed 7. The implementation stays native: no production Rust subprocess, no fixture reads, and no embedded frame-dump table. It preserves the grouped dead branch and existing 1x1/2x1 default tests while adding local RecursiveBacktracker ordering across input plus inner fill cells, Rust-like ParticlePool symbol preallocation, diagonal laser beam painting, spark lifecycle, and default spawn/cooling/final gradients sufficient for the broader LaserEtch parity scenario.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| LaserEtch default 4x3 | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Existing grouped, 1x1 default, and 2x1 default LaserEtch tests were retained. | `swift test --filter laserEtchDefaultAlgorithmMatchesFourByThreeRustRun` — exit 1 after adding the RED test; Swift completed at tick 1 and rendered blank frames while Rust emitted 148 frames. | Same command — exit 0; 1 Swift Testing test passed after native RecursiveBacktracker/laser/spark simulation. | `swift test --filter laserEtch` — exit 0; 4 Swift Testing tests passed, preserving grouped dead branch plus 1x1 and 2x1 default behavior. | Kept the prior bounded 1x1/2x1 branches intact and isolated the broader native path behind the existing default algorithm branch. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 300 --seed 7 --ignore-terminal-dimensions --canvas-width 4 --canvas-height 3 laseretch` from the repository root with stdin `ABC\nD`; Rust emits exactly 148 frames. |
| Focused LaserEtch tests | `swift test --filter laserEtch` — exit 0; 4 Swift Testing tests passed. |
| Parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 39 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 93 Swift Testing tests passed. |
| Diff whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Revert the 4x3 LaserEtch test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, the generalized default native path in `Sources/ttfx-swift/Effects/LaserEtchEffect.swift`, and this section. Keep the grouped branch and bounded 1x1/2x1 LaserEtch default evidence. |

### Task State

- [x] Task 2.2 LaserEtch default breadth now has complete 4x3 native parity evidence in addition to grouped dead-branch and bounded 1x1/2x1 default evidence.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 OrbittingVolley Default Closure Hardening Evidence

Added a second live Rust OrbittingVolley parity gate using the default OrbittingVolley options on a larger 12×6 canvas with input `Swift\nTTE` and seed 42. The run exposed a completion-boundary quirk: when launch delay remains positive after the final glyph settles, Rust emits one additional launcher-visible settled frame before the launcher-hidden completion frame. The Swift effect now preserves the existing configured fast-delay completion while matching that default closure frame. Task 2.2 remains unchecked.

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter orbittingVolleyEffectMatchesADefaultLargerIndependentRustRun` — exit 1; Rust emitted 39 frames, while Swift completed at tick 38 before Rust's final frame and mismatched the launcher-visible settled frame. |
| GREEN | `swift test --filter orbittingVolleyEffectMatchesADefaultLargerIndependentRustRun` — exit 0; 1 Swift Testing test passed after adding the delayed settled-frame branch. |
| Focused OrbittingVolley | `swift test --filter orbittingVolley` — exit 0; both live Rust OrbittingVolley parity tests passed. |
| Effect parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 39 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 93 Swift Testing tests passed. |
| Diff hygiene | `git diff --check` — exit 0. |

### Task State

- [ ] 2.2 remains incomplete: OrbittingVolley now has configured fast-delay and default 12×6 closure parity, but remaining wider task 2.2 effect breadth still requires proof.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.2 Closure Evidence

Task 2.2 is now closed after the bounded slices were followed by non-bounded/general live-Rust parity for each required geometry-heavy effect. The closure does not claim every possible CLI option is exhaustively covered; it records the agreed native Swift behavior now has independent Rust-backed evidence across the named geometry-heavy effects while preserving known Rust quirks.

### Closure validation

| Evidence | Exact result |
|---|---|
| Beams | Live Rust parity covers one-cell, 2×1, 1×2, 2×2, 7×4, and 3×3 cases, including row/column scheduling, fill behavior, final wipe, and diagonal brighten timing. |
| Rings | Live Rust parity covers 1×1, 3×3, 7×4, and 4×2 cases, including start hold, ring-home/final phases, and multi-character sequencing. |
| Blackhole | Live Rust parity covers 1×1, 2×1, and 10-cell consumption/final-gradient behavior without production Rust fallback. |
| LaserEtch | Live Rust parity covers grouped dead branch, default 1×1, default 2×1, and default 4×3 with native RecursiveBacktracker/laser/spark lifecycle simulation. |
| OrbittingVolley | Live Rust parity covers configured 7×4 and default 12×6/larger-input completion behavior. |
| SynthGrid | Live Rust parity covers 1×1, configured 4×3, non-bounded 7×4, and default partitioned 8×6/multi-symbol behavior. |
| Full parity suite | `swift test --filter EffectFrameParityTests` — expected final validation command after this closure update. |
| Full Swift suite | `swift test` — expected final validation command after this closure update. |

### Task State

- [x] 2.2 complete: geometry-heavy effects Beams, Rings, Blackhole, LaserEtch, OrbittingVolley, and SynthGrid have native Swift implementations with independent live Rust parity evidence and preserved quirk notes.
- [ ] 2.3–2.5 and all Phase 3–5 tasks remain untouched.

## Task 2.3 Highlight Effect Evidence

Added native Swift `HighlightEffect` for the Rust `highlight` algorithm. The implementation builds static final-gradient base colors, groups input characters by the configured highlight direction, applies the Rust `in_out_circ` 100-step sequence easer, keeps all characters visible before activation, and plays the HSL brightness-adjusted highlight scene without any production Rust subprocess, fixture reads, or frame-dump tables.

| Evidence | Exact result |
|---|---|
| RED | `swift test --filter highlightEffectMatchesAConfiguredIndependentRustRun` — exit 1; compile failed because `HighlightEffect` was absent. |
| GREEN | `swift test --filter highlightEffectMatchesAConfiguredIndependentRustRun` — exit 0; 1 Swift Testing test passed after native highlight implementation. |
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 150 --seed 7 --ignore-terminal-dimensions --canvas-width 7 --canvas-height 4 highlight --highlight-brightness 1.5 --highlight-direction diagonal_bottom_left_to_top_right --highlight-width 2 --final-gradient-stops 112233 445566 --final-gradient-steps 4 --final-gradient-direction horizontal` with stdin `AB\nCDE`; Rust emits exactly 117 frames. |
| Effect parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 41 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 95 Swift Testing tests passed. |
| Rollback boundary | Revert `Sources/ttfx-swift/Effects/HighlightEffect.swift`, the highlight live-Rust test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, and this section. |

### Task State

- [ ] 2.3 remains incomplete until the remaining assigned task 2.3 effects have native Swift parity evidence.
- [ ] 2.4–2.5 and all Phase 3–5 tasks remain untouched.

## Phase 2.3 MiddleoutEffect Work Unit

This subunit implements the native Swift `middleout` effect only. It adds no Rust production subprocess, fixture table, or frame-dump table to production code; the dedicated parity test invokes live Rust through the existing argument-array `ProcessRunner` harness.

### TDD Cycle Evidence

| Work unit | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| `middleout` | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust frame parity | Existing effect parity harness and prior native effects compiled before adding `MiddleoutEffect`. | `swift test --filter middleoutEffectMatchesAConfiguredIndependentRustRun` exited 1 before source existed: compile failed with `cannot find 'MiddleoutEffect' in scope` plus contextual initializer/member inference errors. | The same command exited 0 after adding `Sources/ttfx-swift/Effects/MiddleoutEffect.swift`; live Rust emitted 68 configured frames and Swift matched every frame byte-for-byte with completion at frame 68. | `swift test --filter EffectFrameParityTests` exercised the full live/fixture effect parity suite including middleout and existing effects. | Corrected the terminal six-frame final-color hold to match Rust's full scene duration, then reran focused parity. |

### Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused middleout test | `swift test --filter middleoutEffectMatchesAConfiguredIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Effect parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 41 Swift Testing tests passed. |
| Full suite | `swift test` — exit 0; 95 Swift Testing tests passed. |
| Diff whitespace | `git diff --check` — exit 0. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/MiddleoutEffect.swift`, revert the middleout test addition in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`, and remove this progress section. |

### Middleout Implementation Notes

`MiddleoutEffect` reproduces Rust's two-phase center-line expansion followed by full expansion, center/full movement speeds and easings, starting color, coordinate-mapped final gradient, center calculation, collision winner ordering by input iteration, and the Rust full-scene terminal color hold. The live parity test covers a horizontal configured run with explicit speeds, easings, starting color, final stops/steps, and horizontal final-gradient direction.

## Task 2.3 Waves Native Swift Slice

This slice adds a native Swift `WavesEffect` backed by a live Rust one-cell parity gate. The implementation ports the Rust wave/final scene timing, cyclic symbol/color distribution, wave-direction group releases, coordinate final-gradient mapping, painter ordering, and the scene-completion quirk where a one-frame wave immediately activates the final scene before the rendered frame. Production Swift does not invoke Rust and does not read fixture/frame-dump tables.

### TDD Cycle Evidence

| Slice | Test file | Layer | Safety net | RED | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| Waves 1x1 live Rust parity | `tests/ttfx-effectsTests/EffectFrameParityTests.swift` | Live Rust parity | Task 2.2 closure tests were present; no production Waves source existed. | `swift test --filter wavesEffectMatchesACompleteOneCellIndependentRustRun` — exit 1 after adding the RED test; compile failed with `cannot find 'WavesEffect' in scope`. | Same command — exit 0; 1 Swift Testing test passed after adding `Sources/ttfx-swift/Effects/WavesEffect.swift`. | `swift test --filter EffectFrameParityTests` — exit 0; 41 Swift Testing tests passed, including the new Waves live Rust run and all existing effect parity gates. | Kept the port effect-local; no shared Core or Rust code change was needed. |

### Validation Evidence

| Evidence | Exact result |
|---|---|
| Live Rust oracle | The new test invokes `/usr/bin/env cargo run --quiet -- --parity-dump --max-frames 80 --seed 1 --ignore-terminal-dimensions --canvas-width 1 --canvas-height 1 waves --wave-symbols x --wave-gradient-stops ffffff --wave-gradient-steps 1 --wave-count 1 --wave-length 1 --final-gradient-stops 112233 445566 --final-gradient-steps 2 --final-gradient-direction horizontal` from the repository root with stdin `A`; Rust emits 31 frames through the test harness. |
| Focused Waves test | `swift test --filter wavesEffectMatchesACompleteOneCellIndependentRustRun` — exit 0; 1 Swift Testing test passed. |
| Effect parity suite | `swift test --filter EffectFrameParityTests` — exit 0; 41 Swift Testing tests passed. |
| Full Swift suite | `swift test` — exit 0; 95 Swift Testing tests passed. |
| Diff hygiene | `git diff --check` — exit 0. |
| Rollback boundary | Remove `Sources/ttfx-swift/Effects/WavesEffect.swift`; revert the Waves test in `tests/ttfx-effectsTests/EffectFrameParityTests.swift`; and remove this section. Keep task 2.2 closure evidence and prior effect implementations. |

### Task State

- [ ] 2.3 remains incomplete unless/until the orchestrator records the remaining task 2.3 effect coverage beyond Waves.
- [ ] 2.4–2.5 and all Phase 3–5 tasks remain untouched.
