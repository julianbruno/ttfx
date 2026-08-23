# Apply Progress: Native Swift Port

**Mode:** Strict TDD
**Delivery:** Single PR with maintainer-approved `size:exception`
**Completed work units:** `wave-0-foundations`, `phase-1-core-engine`, `phase-2-animation-substrate`, `phase-2-animation-composition`, `phase-2-dynamic-gradient-contract`, `phase-2-shared-runtime-execution`, `phase-2-shared-runtime-contract-gaps`, `phase-2-effect-oracle-boundary`, `phase-2-print-effect`, `phase-2-slide-effect`, `phase-2-wipe-effect`, `phase-2-expand-effect`, `phase-2-simple-effects-contract-gaps`
**Attempted work units:** `phase-2-simple-effects-documentary-gate` (QUIRK planning refs added; standalone hash receipt passed; full-suite and generator-check receipts recorded as failing after HEAD checkpoint)
**Status:** 11/27 tasks complete

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
