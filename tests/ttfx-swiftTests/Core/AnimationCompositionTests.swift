import Testing
@testable import TTFXCore

@Test func pathCursorVisitsEverySegmentAppliesEasingAndHonorsHold() {
    let path = ComposedPath(
        id: "route",
        speed: 1,
        easing: .inOutQuad,
        holdTicks: 2,
        waypoints: [.init(column: 1, row: 1), .init(column: 3, row: 1), .init(column: 3, row: 3)]
    )
    var cursor = PathCursor(path: path)

    #expect(cursor.step() == .moving(.init(column: 2, row: 1)))
    #expect(cursor.step() == .moving(.init(column: 3, row: 1)))
    // Rust terminal geometry counts a row as two terminal cells.
    #expect(cursor.step() == .moving(.init(column: 3, row: 1)))
    #expect(cursor.step() == .moving(.init(column: 3, row: 2)))
    #expect(cursor.step() == .moving(.init(column: 3, row: 3)))
    #expect(cursor.step() == .moving(.init(column: 3, row: 3)))
    #expect(cursor.step() == .holding(.init(column: 3, row: 3)))
    #expect(cursor.step() == .holding(.init(column: 3, row: 3)))
    #expect(cursor.step() == .complete(.init(column: 3, row: 3)))
}

@Test func scenePlaybackSynchronizesResetsAndBuildsGradientFrames() throws {
    let frames = try SceneBuilder.gradient(
        symbols: ["*", "+"], durations: [1, 2],
        foreground: .init(stops: [.init(hex: "000000"), .init(hex: "ffffff")], steps: 2),
        background: nil
    )
    var playback = ScenePlayback(scene: .init(id: "sync", frames: frames, sync: .step))

    #expect(playback.step(progress: 0.0)?.visual.codepoint == 42)
    #expect(playback.step(progress: 0.5)?.visual.codepoint == 43)
    playback.reset()
    #expect(playback.step(progress: 0.0)?.visual.codepoint == 42)
}

@Test func schedulingInitializesInputArenaOrdersGroupsAndReleasesPerCharacterPaths() throws {
    let canvas = try Canvas(columns: 4, rows: 2)
    let input = canvas.ingest("AB\nC")
    var runtime = AnimationRuntime(canvas: canvas, input: input, seed: 42)
    let groups = CharacterOrder.groups(in: runtime, order: .rowsTopToBottom)
    var release = ReleasePlan(groups: groups, delay: 1)

    #expect(runtime.terminal.characters.map(\.id) == [.init(rawValue: 0), .init(rawValue: 1), .init(rawValue: 2)])
    #expect(groups == [[.init(rawValue: 0), .init(rawValue: 1)], [.init(rawValue: 2)]])
    #expect(release.next() == [])
    #expect(release.next() == [.init(rawValue: 0)])
    #expect(release.next() == [.init(rawValue: 1)])
    #expect(release.next() == [.init(rawValue: 2)])
    let anchor = runtime.spawn("•", at: .init(column: 4, row: 1), visible: false)
    #expect(anchor == .init(rawValue: 3))
}

@Test func typedActionsChainPathsInlineInTheRustFixtureOrder() {
    // Derived from tests/fixtures/engine_traces.txt lines 135-153.
    var actions = RuntimeActions()
    let id = CharacterID(rawValue: 0)
    actions.register(id, event: .pathComplete, caller: .path("p1"), action: .activatePath("p2"))
    actions.register(id, event: .pathComplete, caller: .path("p2"), action: .activatePath("p3"))
    actions.register(id, event: .pathComplete, caller: .path("p3"), action: .emit(.init(name: "settled")))

    let trace = actions.drainChain(id, startingAt: "p1")

    #expect(trace.map(\.description) == ["activatePath:p2", "activatePath:p3", "emit:settled"])
}

@Test func runtimeEffectBuildsOnceSchedulesInStableOrderAndRecordsRNGRequests() throws {
    var frame = try Frame(columns: 2, rows: 1)
    let configuration = EffectConfiguration(text: "AB", seed: 7)
    let canvas = try Canvas(columns: 2, rows: 1)
    var effect = TraceRuntimeEffect(configuration: configuration, canvas: canvas, input: canvas.ingest(configuration.text), seed: 7)

    #expect(effect.tick(into: &frame) == .running)
    #expect(effect.tick(into: &frame) == .complete)
    #expect(effect.buildCount == 1)
    #expect(effect.runtime.lastUpdatedIDs == [.init(rawValue: 0), .init(rawValue: 1)])
    #expect(effect.runtime.rngRequestTrace == ["release", "release"])
    #expect(frame.storageCapacity == 2)
}

@Test func characterSeedsAndGroupSequencePreserveStableIdentityAndDistinctPaths() throws {
    let seeds = [
        CharacterSeed(symbol: "A", coordinate: .init(column: 2, row: 2)),
        CharacterSeed(symbol: "B", coordinate: .init(column: 1, row: 2)),
        CharacterSeed(symbol: "C", coordinate: .init(column: 1, row: 1)),
    ]
    let sequence = CharacterGroupSequence(seeds: seeds, order: .rowsTopToBottom)
    let canvas = try Canvas(columns: 3, rows: 2)
    var runtime = AnimationRuntime(canvas: canvas, seed: 42)
    let ids = sequence.spawn(into: &runtime)
    let paths = sequence.assign(paths: [
        .init(id: "left", speed: 1, waypoints: [.init(column: 2, row: 2), .init(column: 1, row: 2)]),
        .init(id: "right", speed: 1, waypoints: [.init(column: 1, row: 2), .init(column: 2, row: 2)]),
        .init(id: "down", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 1, row: 2)]),
    ])

    #expect(ids == [.init(rawValue: 0), .init(rawValue: 1), .init(rawValue: 2)])
    #expect(sequence.groups == [[.init(rawValue: 0), .init(rawValue: 1)], [.init(rawValue: 2)]])
    #expect(paths[ids[0]]?.id == "left")
    #expect(paths[ids[1]]?.id == "right")
    #expect(paths[ids[0]] != paths[ids[1]])
}

@Test func pathChainCursorUsesEveryPathResetsAndHonorsControlPoints() {
    let first = ComposedPath(id: "first", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)])
    let second = ComposedPath(
        id: "second", speed: 2, holdTicks: 1,
        waypoints: [.init(column: 2, row: 1), .init(column: 4, row: 3)],
        controls: [[.init(column: 2, row: 3)]]
    )
    var cursor = PathChainCursor(chain: .init(pathIDs: ["first", "second"]), paths: [first, second])

    #expect(cursor.step().pathID == "first")
    #expect(cursor.step().pathID == "second")
    #expect(cursor.step().step != .moving(.init(column: 3, row: 2)))
    cursor.reset()
    #expect(cursor.step().pathID == "first")
}

@Test func sceneSynchronizationModesRemainDistinctAndGradientVariantsPreserveColors() throws {
    let frames = [SceneFrame(symbol: "A", duration: 1), .init(symbol: "B", duration: 1), .init(symbol: "C", duration: 1)]
    var step = ScenePlayback(scene: .init(id: "step", frames: frames, sync: .step))
    var progress = ScenePlayback(scene: .init(id: "progress", frames: frames, sync: .progress))
    var distance = ScenePlayback(scene: .init(id: "distance", frames: frames, sync: .distance))

    #expect(step.step(metrics: .init(step: 2, progress: 0.1, distance: 1, totalDistance: 100))?.visual.codepoint == 67)
    #expect(progress.step(metrics: .init(step: 2, progress: 0.1, distance: 99, totalDistance: 100))?.visual.codepoint == 65)
    #expect(distance.step(metrics: .init(step: 2, progress: 0.1, distance: 99, totalDistance: 100))?.visual.codepoint == 67)

    let foreground = try Gradient(stops: [.init(hex: "ff0000"), .init(hex: "0000ff")], steps: 1)
    let background = try Gradient(stops: [.init(hex: "00ff00"), .init(hex: "ffffff")], steps: 1)
    let colored = try SceneBuilder.gradient(symbols: ["*"], durations: [1], foreground: foreground, background: background)
    let clear = try SceneBuilder.gradient(symbols: ["*", "+"], durations: [1], foreground: nil, background: nil)
    let mapping = try foreground.coordinateColorMapping(minRow: 1, maxRow: 1, minColumn: 1, maxColumn: 2, direction: .horizontal)

    #expect(colored[0].visual.foreground == 0xff0000)
    #expect(colored[0].visual.background == 0x00ff00)
    #expect(colored[1].visual.foreground == 0x0000ff)
    #expect(colored[1].visual.background == 0xffffff)
    #expect(clear.map(\.visual.codepoint) == [42, 43])
    #expect(clear.allSatisfy { $0.visual.foreground == 0 && $0.visual.background == 0 })
    #expect(mapping.entries.map(\.color.hex) == ["ff0000", "0000ff"])
}

@Test func dynamicGradientSidesBridgeFromEachPreexistingColor() throws {
    let source = try Gradient(stops: [.init(hex: "ff0000"), .init(hex: "0000ff")], steps: 1)
    let dynamic = try SceneBuilder.gradient(
        symbols: ["*"], durations: [1], foreground: source, background: source,
        foregroundBehavior: .dynamic(preexisting: .init(hex: "00ff00")),
        backgroundBehavior: .dynamic(preexisting: .init(hex: "ffff00"))
    )
    let staticFrames = try SceneBuilder.gradient(
        symbols: ["*"], durations: [1], foreground: source, background: source
    )
    let noColor = try SceneBuilder.gradient(
        symbols: ["*"], durations: [1], foreground: source, background: nil,
        foregroundBehavior: .dynamic(preexisting: nil)
    )
    let mapping = try source.coordinateColorMapping(
        minRow: 1, maxRow: 1, minColumn: 1, maxColumn: 2, direction: .horizontal
    )

    #expect(staticFrames.map(\.visual.foreground) == [0xff0000, 0x0000ff])
    #expect(dynamic.map(\.visual.foreground) == [0x0000ff, 0x00ff00])
    #expect(dynamic.map(\.visual.background) == [0x0000ff, 0xffff00])
    #expect(noColor.allSatisfy { $0.visual.foreground == 0 && $0.visual.background == 0 })
    #expect(mapping.entries.map(\.color.hex) == ["ff0000", "0000ff"])
}

@Test func dynamicGradientInterpolationUsesTheSourceLengthForEachCell() throws {
    let source = try Gradient(stops: [.init(hex: "000000"), .init(hex: "090909")], steps: 3)
    let frames = try SceneBuilder.gradient(
        symbols: ["A", "B"], durations: [1, 2], foreground: source, background: nil,
        foregroundBehavior: .dynamic(preexisting: .init(hex: "0c0f12"))
    )

    #expect(frames.map(\.visual.foreground) == [0x090909, 0x0a0b0c, 0x0b0d0f, 0x0c0f12])
    #expect(frames.map(\.visual.background) == [0, 0, 0, 0])
    #expect(frames.map(\.duration) == [1, 2, 1, 2])
}

@Test func runtimeRecordsExactRustXoshiroDrawTraceInRequestOrder() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    var runtime = AnimationRuntime(canvas: canvas, seed: 42)

    let draws = [runtime.requestRandomUInt64(named: "color"), runtime.requestRandomUInt64(named: "symbol")]

    #expect(draws == [15_021_278_609_987_233_951, 5_881_210_131_331_364_753])
    #expect(runtime.rngRequestTrace == ["color", "symbol"])
}

private struct TraceRuntimeEffect: RuntimeEffect {
    let configuration: EffectConfiguration
    let canvas: Canvas
    let input: InputText
    var runtime: AnimationRuntime
    var buildCount = 0
    var ticks = 0

    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.configuration = configuration
        self.canvas = canvas
        self.input = input
        runtime = .init(canvas: canvas, input: input, seed: seed)
    }

    mutating func buildRuntime() {
        buildCount += 1
        for character in runtime.terminal.characters {
            runtime.addPath(character.id, .init(id: "input", speed: 0.5, waypoints: [character.currentCoordinate, .init(column: character.currentCoordinate.column + 1, row: character.currentCoordinate.row)]))
            runtime.activatePath(character.id, named: "input")
        }
    }

    mutating func scheduleTick() {
        ticks += 1
        _ = runtime.requestRandomUInt64(named: "release")
    }
}
