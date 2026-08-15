struct RuntimeComposedMotion: Sendable {
    var cursor: PathChainCursor
    var activePathID: String
    var step = 0
    var distance = 0.0
    let totalDistance: Double

    init(paths: [ComposedPath], chain: PathChain) {
        cursor = .init(chain: chain, paths: paths)
        activePathID = chain.pathIDs[0]
        totalDistance = paths.reduce(0) { partial, path in
            partial + path.segments.reduce(0) { $0 + $1.distance }
        }
    }
}

struct RuntimeComposedScene: Sendable {
    var playback: ScenePlayback

    init(scene: ComposedScene) {
        playback = .init(scene: scene)
    }
}

public extension AnimationRuntime {
    mutating func installComposedPaths(_ paths: [ComposedPath], for id: CharacterID) {
        precondition(paths.map(\.id).count == Set(paths.map(\.id)).count, "duplicate composed path id")
        composedPaths[id] = Dictionary(uniqueKeysWithValues: paths.map { ($0.id, $0) })
    }

    mutating func installAssignedPaths(_ assignments: [CharacterID: ComposedPath]) {
        for (id, path) in assignments.sorted(by: { $0.key < $1.key }) {
            installComposedPaths([path], for: id)
        }
    }

    mutating func activateComposedPath(_ id: CharacterID, named name: String) {
        activateComposedPath(id, chain: .init(pathIDs: [name]))
    }

    mutating func activateComposedPath(_ id: CharacterID, chain: PathChain) {
        guard let stored = composedPaths[id] else { preconditionFailure("composed paths not installed") }
        let paths = chain.pathIDs.map { pathID -> ComposedPath in
            guard let path = stored[pathID] else { preconditionFailure("composed path not found") }
            return path
        }
        composedMotions[id] = .init(paths: paths, chain: chain)
        dispatchRuntimeActions(id, event: .pathActivated, caller: .path(chain.pathIDs[0]))
    }

    func activeComposedPathID(for id: CharacterID) -> String? {
        composedMotions[id]?.activePathID
    }

    mutating func installComposedScene(_ scene: ComposedScene, for id: CharacterID) {
        composedScenes[id, default: [:]][scene.id] = .init(scene: scene)
    }

    mutating func activateComposedScene(_ id: CharacterID, named name: String) {
        guard var scene = composedScenes[id]?[name] else { preconditionFailure("composed scene not found") }
        scene.playback.reset()
        composedScenes[id]?[name] = scene
        activeComposedSceneIDs[id] = name
        dispatchRuntimeActions(id, event: .sceneActivated, caller: .scene(name))
    }

    mutating func resetComposedScene(_ id: CharacterID, named name: String) {
        guard var scene = composedScenes[id]?[name] else { preconditionFailure("composed scene not found") }
        scene.playback.reset()
        terminal.characters[id.rawValue].visual = scene.playback.scene.frames[0].visual
        composedScenes[id]?[name] = scene
    }

    mutating func registerRuntimeAction(_ id: CharacterID, event: RuntimeEvent, caller: EventCaller, action: RuntimeAction) {
        runtimeActions.register(id, event: event, caller: caller, action: action)
    }

    @discardableResult
    mutating func spawnAnchor(at coordinate: Coordinate, symbol: Character = " ", layer: Int = 0) -> CharacterID {
        addCharacter(symbol, at: coordinate, visible: false, layer: layer)
    }

    mutating func retire(_ id: CharacterID) {
        terminal.characters[id.rawValue].visible = false
        terminal.characters[id.rawValue].motion.activePathID = nil
        terminal.characters[id.rawValue].animation.activeSceneID = nil
        composedMotions[id] = nil
        activeComposedSceneIDs[id] = nil
        completedComposedMetrics[id] = nil
        retiredIDs.insert(id)
    }

    mutating func schedule(releases plan: ReleasePlan) {
        releasePlans.append(plan)
    }

    mutating func drainEmittedEvents() -> [EffectEvent] {
        defer { emittedEvents.removeAll(keepingCapacity: true) }
        return emittedEvents
    }

    mutating func randomInteger(named name: String, in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound, "empty integer range")
        return range.lowerBound + Int(randomBelow(UInt64(range.upperBound - range.lowerBound + 1), named: name))
    }

    mutating func randomInteger(named name: String, in range: Range<Int>) -> Int {
        precondition(range.lowerBound < range.upperBound, "empty integer range")
        return range.lowerBound + Int(randomBelow(UInt64(range.upperBound - range.lowerBound), named: name))
    }

    mutating func randomChoiceIndex(named name: String, count: Int) -> Int {
        precondition(count > 0, "choice on empty sequence")
        return Int(randomBelow(UInt64(count), named: name))
    }

    mutating func randomChoice<T>(named name: String, from values: [T]) -> T {
        values[randomChoiceIndex(named: name, count: values.count)]
    }

    mutating func randomShuffle<T>(named name: String, _ values: inout [T]) {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            values.swapAt(index, Int(randomBelow(UInt64(index + 1), named: name)))
        }
    }

    mutating func randomUniform(named name: String, lower: Double, upper: Double) -> Double {
        lower + (upper - lower) * Double(drawRandom(named: name) >> 11) * (1.0 / Double(UInt64(1) << 53))
    }
}

extension AnimationRuntime {
    mutating func drawRandom(named name: String) -> UInt64 {
        let value = rng.nextUInt64()
        rngRequestTrace.append(name)
        rngValueTrace.append(value)
        return value
    }

    mutating func randomBelow(_ upperBound: UInt64, named name: String) -> UInt64 {
        precondition(upperBound > 0, "randomBelow(0)")
        let bitCount = 64 - (upperBound - 1).leadingZeroBitCount
        while true {
            let value = drawRandom(named: name) >> (64 - max(bitCount, 1))
            if value < upperBound { return value }
        }
    }

    mutating func releaseScheduledCharacters() {
        var remaining: [ReleasePlan] = []
        for var plan in releasePlans {
            while !plan.isComplete {
                let released = plan.next()
                guard !released.isEmpty else { break }
                let active = released.filter { !retiredIDs.contains($0) }
                guard !active.isEmpty else { continue }
                for id in active {
                    terminal.characters[id.rawValue].visible = true
                }
                break
            }
            if !plan.isComplete { remaining.append(plan) }
        }
        releasePlans = remaining
    }

    mutating func stepComposedMotion(_ id: CharacterID) {
        guard var motion = composedMotions[id] else { return }
        let previous = terminal.characters[id.rawValue].currentCoordinate
        let result = motion.cursor.step()
        motion.activePathID = result.pathID
        switch result.step {
        case let .moving(coordinate), let .holding(coordinate):
            terminal.characters[id.rawValue].currentCoordinate = coordinate
            motion.step += 1
            motion.distance += Geometry.lineLength(from: previous, to: coordinate)
            composedMotions[id] = motion
        case let .complete(coordinate):
            terminal.characters[id.rawValue].currentCoordinate = coordinate
            motion.step += 1
            motion.distance += Geometry.lineLength(from: previous, to: coordinate)
            completedComposedMetrics[id] = sceneMetrics(for: motion)
            composedMotions[id] = nil
            dispatchRuntimeActions(id, event: .pathComplete, caller: .path(result.pathID))
        }
    }

    mutating func stepComposedScene(_ id: CharacterID) {
        guard let name = activeComposedSceneIDs[id], var scene = composedScenes[id]?[name] else { return }
        let metrics: SceneMetrics
        if let motion = composedMotions[id] {
            metrics = sceneMetrics(for: motion)
        } else if let completed = completedComposedMetrics[id] {
            metrics = completed
        } else {
            metrics = .init(step: 0, progress: 0, distance: 0, totalDistance: 0)
        }
        let frame = scene.playback.scene.sync == .none ? scene.playback.step() : scene.playback.step(metrics: metrics)
        if let frame { terminal.characters[id.rawValue].visual = frame.visual }
        composedScenes[id]?[name] = scene
        let finishesWithPath = completedComposedMetrics[id] != nil && scene.playback.scene.sync != .none && !scene.playback.scene.loop
        if scene.playback.isComplete || finishesWithPath {
            activeComposedSceneIDs[id] = nil
            completedComposedMetrics[id] = nil
            dispatchRuntimeActions(id, event: .sceneComplete, caller: .scene(name))
        }
    }

    mutating func dispatchRuntimeActions(_ id: CharacterID, event: RuntimeEvent, caller: EventCaller) {
        for action in runtimeActions.actions(for: id, event: event, caller: caller) {
            runtimeActionTrace.append(action)
            switch action {
            case let .activatePath(name): activateComposedPath(id, named: name)
            case let .activateScene(name): activateComposedScene(id, named: name)
            case let .setLayer(layer): terminal.characters[id.rawValue].layer = layer
            case let .setVisibility(visible): terminal.characters[id.rawValue].visible = visible
            case let .setCoordinate(coordinate): terminal.characters[id.rawValue].currentCoordinate = coordinate
            case let .emit(event): emittedEvents.append(event)
            }
        }
    }

    func sceneMetrics(for motion: RuntimeComposedMotion) -> SceneMetrics {
        .init(
            step: motion.step,
            progress: motion.totalDistance == 0 ? 0 : motion.distance / motion.totalDistance,
            distance: motion.distance,
            totalDistance: motion.totalDistance
        )
    }
}
