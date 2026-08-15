import Testing
@testable import TTFXCore

@Test func runtimeExecutesComposedChainsAndSynchronizedScenes() throws {
    let canvas = try Canvas(columns: 4, rows: 2)
    var runtime = AnimationRuntime(canvas: canvas, seed: 42)
    let id = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    let first = ComposedPath(id: "first", speed: 1, holdTicks: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])
    let second = ComposedPath(
        id: "second", speed: 1, easing: .inOutQuad,
        waypoints: [.init(column: 2, row: 1), .init(column: 4, row: 2)],
        controls: [[.init(column: 2, row: 2)]]
    )
    let gradient = try Gradient(stops: [.init(hex: "ff0000"), .init(hex: "0000ff")], steps: 1)
    let frames = try SceneBuilder.gradient(symbols: ["A"], durations: [1], foreground: gradient, background: nil)

    runtime.installComposedPaths([first, second], for: id)
    runtime.activateComposedPath(id, chain: .init(pathIDs: ["first", "second"]))
    runtime.installComposedScene(.init(id: "color", frames: frames, sync: .distance), for: id)
    runtime.activateComposedScene(id, named: "color")

    var frame = try Frame(columns: 4, rows: 2)
    #expect(runtime.tick(into: &frame) == .running)
    #expect(runtime.character(id).currentCoordinate == .init(column: 2, row: 1))
    #expect(frame[column: 2, row: 1].foreground == 0xff0000)
    runtime.resetComposedScene(id, named: "color")
    #expect(runtime.tick(into: &frame) == .running)
    #expect(runtime.character(id).visual.foreground == 0xff0000)
    for _ in 0..<8 { _ = runtime.tick(into: &frame) }
    #expect(runtime.activeComposedPathID(for: id) == nil)
}

@Test func runtimeDispatchesTypedActionsAndRecordsExactNamedRandomDraws() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 42)
    let id = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: false)
    let first = ComposedPath(id: "first", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])
    let second = ComposedPath(id: "second", speed: 1, waypoints: [.init(column: 2, row: 1), .init(column: 1, row: 1)])
    runtime.installComposedPaths([first, second], for: id)
    runtime.registerRuntimeAction(id, event: .pathComplete, caller: .path("first"), action: .activatePath("second"))
    runtime.registerRuntimeAction(id, event: .pathActivated, caller: .path("second"), action: .setLayer(2))
    runtime.registerRuntimeAction(id, event: .pathComplete, caller: .path("second"), action: .setVisibility(true))
    runtime.activateComposedPath(id, named: "first")

    #expect(runtime.randomInteger(named: "release", in: 1...3) == 2)
    #expect(runtime.randomUniform(named: "speed", lower: 0, upper: 1) > 0)
    #expect(runtime.rngRequestTrace == ["release", "release", "speed"])
    #expect(runtime.rngValueTrace == [15_021_278_609_987_233_951, 5_881_210_131_331_364_753, 18_149_643_915_985_481_100])

    var frame = try Frame(columns: 2, rows: 1)
    _ = runtime.tick(into: &frame)
    _ = runtime.tick(into: &frame)
    #expect(runtime.activeComposedPathID(for: id) == "second")
    #expect(runtime.character(id).layer == 2)
    _ = runtime.tick(into: &frame)
    _ = runtime.tick(into: &frame)
    #expect(runtime.character(id).visible)
    #expect(runtime.runtimeActionTrace.map(\.description) == ["activatePath:second", "setLayer:2", "setVisibility:true"])
}

@Test func runtimeSchedulesReleasesRetiresAnchorsAndDrivesComposedEffects() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 7)
    let released = runtime.addCharacter("R", at: .init(column: 1, row: 1), visible: false)
    let anchor = runtime.spawnAnchor(at: .init(column: 2, row: 1))
    runtime.schedule(releases: .init(groups: [[released]], delay: 0))
    runtime.retire(anchor)
    var frame = try Frame(columns: 2, rows: 1)
    _ = runtime.tick(into: &frame)
    #expect(runtime.character(released).visible)
    #expect(!runtime.character(anchor).visible)

    var effect = SharedRuntimeFixture(configuration: .init(text: "A", seed: 7), canvas: canvas, input: canvas.ingest("A"), seed: 7)
    #expect(effect.tick(into: &frame) == .running)
    #expect(effect.buildCount == 1)
    #expect(frame[column: 2, row: 1].codepoint == 65)
}

@Test func runtimeReleasesGroupsInOrderAndUpdatesComposedCharactersStably() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 9)
    let first = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: false)
    let second = runtime.addCharacter("B", at: .init(column: 2, row: 1), visible: false)
    let scene = ComposedScene(id: "steady", frames: [.init(symbol: "*", duration: 1)], loop: true)
    runtime.installComposedScene(scene, for: first)
    runtime.installComposedScene(scene, for: second)
    runtime.activateComposedScene(first, named: "steady")
    runtime.activateComposedScene(second, named: "steady")
    runtime.schedule(releases: .init(groups: [[first, second]], delay: 1))

    var frame = try Frame(columns: 2, rows: 1)
    _ = runtime.tick(into: &frame)
    #expect(!runtime.character(first).visible && !runtime.character(second).visible)
    _ = runtime.tick(into: &frame)
    #expect(runtime.character(first).visible && !runtime.character(second).visible)
    _ = runtime.tick(into: &frame)
    #expect(runtime.character(second).visible)
    #expect(runtime.lastUpdatedIDs == [first, second])
}

@Test func namedChoiceUsesTheSameRejectedDrawSequenceAsRust() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 42)

    #expect(runtime.randomChoiceIndex(named: "rain-color", count: 3) == 1)
    #expect(runtime.rngRequestTrace == ["rain-color", "rain-color"])
    #expect(runtime.rngValueTrace == [15_021_278_609_987_233_951, 5_881_210_131_331_364_753])
}

@Test func completedComposedScenesDispatchAndDoNotKeepRuntimeAlive() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 1)
    let id = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    runtime.installComposedScene(.init(id: "once", frames: [.init(symbol: "*", duration: 1)]), for: id)
    runtime.registerRuntimeAction(id, event: .sceneComplete, caller: .scene("once"), action: .setLayer(3))
    runtime.activateComposedScene(id, named: "once")

    #expect(runtime.update() == .complete)
    #expect(runtime.character(id).visual.codepoint == 42)
    #expect(runtime.character(id).layer == 3)
    #expect(runtime.runtimeActionTrace.map(\.description) == ["setLayer:3"])

    runtime.installComposedScene(.init(id: "loop", frames: [.init(symbol: "+", duration: 1)], loop: true), for: id)
    runtime.activateComposedScene(id, named: "loop")
    #expect(runtime.update() == .running)
    runtime.resetComposedScene(id, named: "loop")
    #expect(runtime.update() == .running)
    #expect(runtime.character(id).visual.codepoint == 43)
}

@Test func emittedActionsReachRuntimeEffectsAndAssignedPathsExecuteIndependently() throws {
    let canvas = try Canvas(columns: 3, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 2)
    let first = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    let second = runtime.addCharacter("B", at: .init(column: 3, row: 1), visible: true)
    let assignments: [CharacterID: ComposedPath] = [
        first: .init(id: "right", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)]),
        second: .init(id: "left", speed: 1, waypoints: [.init(column: 3, row: 1), .init(column: 2, row: 1)]),
    ]
    runtime.installAssignedPaths(assignments)
    runtime.registerRuntimeAction(first, event: .pathComplete, caller: .path("right"), action: .emit(.init(name: "landed")))
    runtime.activateComposedPath(first, named: "right")
    runtime.activateComposedPath(second, named: "left")

    _ = runtime.update()
    #expect(runtime.character(first).currentCoordinate == .init(column: 2, row: 1))
    #expect(runtime.character(second).currentCoordinate == .init(column: 2, row: 1))
    _ = runtime.update()
    #expect(runtime.drainEmittedEvents() == [.init(name: "landed")])

    var effect = EmittingRuntimeFixture(configuration: .init(text: "A", seed: 2), canvas: canvas, input: canvas.ingest("A"), seed: 2)
    var frame = try Frame(columns: 3, rows: 1)
    _ = effect.tick(into: &frame)
    _ = effect.tick(into: &frame)
    #expect(effect.receivedEvents == [.init(name: "complete")])
}

@Test func retiringActiveAnchorsPrunesScheduledWorkAndRuntimeEffectsComplete() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 3)
    let anchor = runtime.spawnAnchor(at: .init(column: 1, row: 1), symbol: "o")
    let released = runtime.addCharacter("R", at: .init(column: 2, row: 1), visible: false)
    runtime.installComposedPaths([.init(id: "anchor", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])], for: anchor)
    runtime.activateComposedPath(anchor, named: "anchor")
    runtime.schedule(releases: .init(groups: [[anchor, released]], delay: 0))
    runtime.retire(anchor)

    var frame = try Frame(columns: 2, rows: 1)
    #expect(runtime.tick(into: &frame) == .complete)
    #expect(runtime.lastUpdatedIDs.isEmpty)
    #expect(!runtime.character(anchor).visible && runtime.character(released).visible)
    #expect(frame[column: 1, row: 1] == .blank)

    var effect = CompletingRuntimeFixture(configuration: .init(text: "A", seed: 3), canvas: canvas, input: canvas.ingest("A"), seed: 3)
    #expect(effect.tick(into: &frame) == .running)
    #expect(effect.tick(into: &frame) == .complete)
    #expect(effect.buildCount == 1)
}

@Test func diagonalGroupsReleaseInCanonicalOrder() throws {
    let seeds = [
        CharacterSeed(symbol: "A", coordinate: .init(column: 1, row: 2)),
        CharacterSeed(symbol: "B", coordinate: .init(column: 1, row: 1)),
        CharacterSeed(symbol: "C", coordinate: .init(column: 2, row: 1)),
    ]
    let sequence = CharacterGroupSequence(seeds: seeds, order: .diagonalsTopLeftToBottomRight)
    var release = ReleasePlan(groups: sequence.groups, delay: 0)

    #expect(sequence.groups == [[.init(rawValue: 1)], [.init(rawValue: 0), .init(rawValue: 2)]])
    #expect(release.next() == [.init(rawValue: 1)])
    #expect(release.next() == [.init(rawValue: 0)])
    #expect(release.next() == [.init(rawValue: 2)])
}

@Test func resettingSynchronizedScenesRestoresTheirInitialFrameImmediately() throws {
    let canvas = try Canvas(columns: 3, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 4)
    let id = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    let path = ComposedPath(id: "sync", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 3, row: 1)])
    let scene = ComposedScene(id: "sync", frames: [.init(symbol: "A", duration: 1), .init(symbol: "B", duration: 1)], sync: .step)
    runtime.installComposedPaths([path], for: id)
    runtime.installComposedScene(scene, for: id)
    runtime.activateComposedPath(id, named: "sync")
    runtime.activateComposedScene(id, named: "sync")

    _ = runtime.update()
    #expect(runtime.character(id).visual.codepoint == 66)
    runtime.resetComposedScene(id, named: "sync")
    #expect(runtime.character(id).visual.codepoint == 65)
}

private struct SharedRuntimeFixture: RuntimeEffect {
    let configuration: EffectConfiguration
    let canvas: Canvas
    let input: InputText
    var runtime: AnimationRuntime
    var buildCount = 0

    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.configuration = configuration
        self.canvas = canvas
        self.input = input
        runtime = .init(canvas: canvas, input: input, seed: seed)
    }

    mutating func buildRuntime() {
        buildCount += 1
        let id = runtime.terminal.characters[0].id
        let path = ComposedPath(id: "input", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])
        runtime.installComposedPaths([path], for: id)
        runtime.activateComposedPath(id, named: "input")
        runtime.setVisibility(id, true)
    }

    mutating func scheduleTick() {}
}

private struct EmittingRuntimeFixture: RuntimeEffect {
    let configuration: EffectConfiguration
    let canvas: Canvas
    let input: InputText
    var runtime: AnimationRuntime
    var receivedEvents: [EffectEvent] = []

    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.configuration = configuration
        self.canvas = canvas
        self.input = input
        runtime = .init(canvas: canvas, input: input, seed: seed)
    }

    mutating func buildRuntime() {
        let id = runtime.terminal.characters[0].id
        let path = ComposedPath(id: "input", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])
        runtime.installComposedPaths([path], for: id)
        runtime.registerRuntimeAction(id, event: .pathComplete, caller: .path("input"), action: .emit(.init(name: "complete")))
        runtime.activateComposedPath(id, named: "input")
        runtime.setVisibility(id, true)
    }

    mutating func scheduleTick() {}
    mutating func receiveRuntimeEvent(_ event: EffectEvent) { receivedEvents.append(event) }
}

private struct CompletingRuntimeFixture: RuntimeEffect {
    let configuration: EffectConfiguration
    let canvas: Canvas
    let input: InputText
    var runtime: AnimationRuntime
    var buildCount = 0

    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.configuration = configuration
        self.canvas = canvas
        self.input = input
        runtime = .init(canvas: canvas, input: input, seed: seed)
    }

    mutating func buildRuntime() {
        buildCount += 1
        let id = runtime.terminal.characters[0].id
        let path = ComposedPath(id: "input", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])
        runtime.installComposedPaths([path], for: id)
        runtime.installComposedScene(.init(id: "once", frames: [.init(symbol: "A", duration: 1)]), for: id)
        runtime.activateComposedPath(id, named: "input")
        runtime.activateComposedScene(id, named: "once")
        runtime.setVisibility(id, true)
    }

    mutating func scheduleTick() {}
}
