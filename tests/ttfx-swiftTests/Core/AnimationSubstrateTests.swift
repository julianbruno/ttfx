import Testing
@testable import TTFXCore

@Test func terminalKeepsStableIdentityAndGroupsCharactersInInputOrder() throws {
    var terminal = try TerminalModel(canvas: .init(columns: 4, rows: 3))
    let first = terminal.addCharacter("A", at: .init(column: 2, row: 2))
    let second = terminal.addCharacter("B", at: .init(column: 1, row: 2))
    let third = terminal.addCharacter("C", at: .init(column: 1, row: 1))

    #expect([first, second, third] == [.init(rawValue: 0), .init(rawValue: 1), .init(rawValue: 2)])
    #expect(terminal.groupedIDs(.rowsTopToBottom) == [[first, second], [third]])
    #expect(terminal.groupedIDs(.columnsLeftToRight) == [[second, third], [first]])
}

@Test func rendererHonorsVisibilityAndResolvesCollisionsByLayerThenIdentity() throws {
    var runtime = try AnimationRuntime(canvas: .init(columns: 2, rows: 1))
    let lower = runtime.addCharacter("A", at: .init(column: 1, row: 1), layer: 3)
    let higher = runtime.addCharacter("B", at: .init(column: 1, row: 1), layer: 3)
    let hidden = runtime.addCharacter("C", at: .init(column: 2, row: 1), visible: false)
    var frame = try Frame(columns: 2, rows: 1)

    runtime.render(into: &frame)

    #expect(frame[column: 1, row: 1].codepoint == 66)
    #expect(frame[column: 2, row: 1] == .blank)
    runtime.setVisibility(lower, true)
    runtime.setLayer(higher, 2)
    runtime.setVisibility(hidden, true)
    runtime.render(into: &frame)
    #expect(frame[column: 1, row: 1].codepoint == 65)
    #expect(frame[column: 2, row: 1].codepoint == 67)
}

@Test func motionInterpolatesBeforeAnimationAndHonorsTerminalHold() throws {
    var runtime = try AnimationRuntime(canvas: .init(columns: 5, rows: 1))
    let id = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    runtime.addPath(id, .init(id: "move", speed: 1, holdTicks: 2, loop: false, waypoints: [
        .init(column: 1, row: 1), .init(column: 3, row: 1),
    ]))
    runtime.activatePath(id, named: "move")

    #expect(runtime.update() == .running)
    #expect(runtime.character(id).currentCoordinate == .init(column: 2, row: 1))
    #expect(runtime.update() == .running)
    #expect(runtime.character(id).currentCoordinate == .init(column: 3, row: 1))
    #expect(runtime.update() == .running)
    #expect(runtime.character(id).currentCoordinate == .init(column: 3, row: 1))
    #expect(runtime.update() == .complete)
    #expect(runtime.character(id).motion.activePathID == nil)
}

@Test func scenesRespectFrameDurationsAndLooping() throws {
    var runtime = try AnimationRuntime(canvas: .init(columns: 1, rows: 1))
    let finite = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    runtime.addScene(finite, .init(id: "finite", frames: [
        .init(symbol: "X", duration: 2), .init(symbol: "Y", duration: 1),
    ]))
    runtime.activateScene(finite, named: "finite")

    #expect(runtime.update() == .running)
    #expect(runtime.character(finite).visual.codepoint == 88)
    #expect(runtime.update() == .running)
    #expect(runtime.character(finite).visual.codepoint == 89)
    #expect(runtime.update() == .complete)

    let looping = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    runtime.addScene(looping, .init(id: "loop", frames: [.init(symbol: "L", duration: 1)], loop: true))
    runtime.activateScene(looping, named: "loop")
    #expect(runtime.update() == .running)
    #expect(runtime.character(looping).visual.codepoint == 76)
}

@Test func eventsAreTypedInlineReentrantAndRegistrationOrdered() throws {
    var runtime = try AnimationRuntime(canvas: .init(columns: 2, rows: 1))
    let id = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    runtime.addPath(id, .init(id: "first", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)]))
    runtime.addScene(id, .init(id: "flash", frames: [.init(symbol: "F", duration: 1)]))
    runtime.register(id, event: .pathActivated, caller: .path("first"), action: .setLayer(2))
    runtime.register(id, event: .pathActivated, caller: .path("first"), action: .activateScene("flash"))
    runtime.register(id, event: .sceneActivated, caller: .scene("flash"), action: .setVisibility(false))

    runtime.activatePath(id, named: "first")

    #expect(runtime.eventTrace == [
        .init(character: id, event: .pathActivated, caller: .path("first")),
        .init(character: id, event: .sceneActivated, caller: .scene("flash")),
    ])
    #expect(runtime.character(id).layer == 2)
    #expect(runtime.character(id).visible == false)
}

@Test func runtimeOrchestratesOrderedTicksRenderingCompletionAndFixedFrameCapacity() throws {
    var runtime = try AnimationRuntime(canvas: .init(columns: 2, rows: 1))
    let first = runtime.addCharacter("A", at: .init(column: 1, row: 1), visible: true)
    let second = runtime.addCharacter("B", at: .init(column: 2, row: 1), visible: true)
    runtime.addPath(first, .init(id: "a", speed: 1, waypoints: [.init(column: 1, row: 1), .init(column: 2, row: 1)]))
    runtime.addPath(second, .init(id: "b", speed: 1, waypoints: [.init(column: 2, row: 1), .init(column: 1, row: 1)]))
    runtime.activatePath(second, named: "b")
    runtime.activatePath(first, named: "a")
    var frame = try Frame(columns: 2, rows: 1)
    let capacity = frame.storageCapacity

    #expect(runtime.tick(into: &frame) == .complete)
    #expect(runtime.lastUpdatedIDs == [first, second])
    #expect(frame.storageCapacity == capacity)
    #expect(frame[column: 1, row: 1].codepoint == 66)
    #expect(frame[column: 2, row: 1].codepoint == 65)
}

@Test func runtimeRetainsSeededRNGStateForDeterministicEffectScheduling() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    var first = AnimationRuntime(canvas: canvas, seed: 42)
    var second = AnimationRuntime(canvas: canvas, seed: 42)
    var different = AnimationRuntime(canvas: canvas, seed: 7)

    #expect(first.nextRandomUInt64() == second.nextRandomUInt64())
    #expect(first.nextRandomUInt64() == second.nextRandomUInt64())
    #expect(first.nextRandomUInt64() != different.nextRandomUInt64())
}
