public struct CharacterID: RawRepresentable, Comparable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct CharacterVisual: Equatable, Sendable {
    public var codepoint: UInt32
    public var foreground: UInt32
    public var background: UInt32

    public init(symbol: Character, foreground: UInt32 = 0, background: UInt32 = 0) {
        self.codepoint = symbol.unicodeScalars.first?.value ?? Cell.blank.codepoint
        self.foreground = foreground
        self.background = background
    }
}

public struct MotionPath: Equatable, Sendable {
    public let id: String
    public let speed: Double
    public let holdTicks: Int
    public let loop: Bool
    public let waypoints: [Coordinate]

    public init(id: String, speed: Double, holdTicks: Int = 0, loop: Bool = false, waypoints: [Coordinate]) {
        precondition(speed > 0, "path speed must be positive")
        precondition(holdTicks >= 0, "hold ticks must not be negative")
        precondition(waypoints.count >= 2, "a path requires two waypoints")
        self.id = id
        self.speed = speed
        self.holdTicks = holdTicks
        self.loop = loop
        self.waypoints = waypoints
    }
}

public struct MotionState: Equatable, Sendable {
    public var paths: [MotionPath] = []
    public var activePathID: String?
    fileprivate var progress = 0
    fileprivate var holdingTicksRemaining = 0

    public init() {}
}

public struct SceneFrame: Equatable, Sendable {
    public let visual: CharacterVisual
    public let duration: Int

    public init(symbol: Character, duration: Int, foreground: UInt32 = 0, background: UInt32 = 0) {
        precondition(duration > 0, "scene frame duration must be positive")
        self.visual = .init(symbol: symbol, foreground: foreground, background: background)
        self.duration = duration
    }
}

public struct AnimationScene: Equatable, Sendable {
    public let id: String
    public let frames: [SceneFrame]
    public let loop: Bool

    public init(id: String, frames: [SceneFrame], loop: Bool = false) {
        precondition(!frames.isEmpty, "a scene requires a frame")
        self.id = id
        self.frames = frames
        self.loop = loop
    }
}

public struct AnimationState: Equatable, Sendable {
    public var scenes: [AnimationScene] = []
    public var activeSceneID: String?
    fileprivate var frameIndex = 0
    fileprivate var ticksRemaining = 0

    public init() {}
}

public enum RuntimeEvent: Equatable, Sendable {
    case pathActivated
    case pathComplete
    case sceneActivated
    case sceneComplete
}

public enum EventCaller: Equatable, Sendable {
    case path(String)
    case scene(String)
}

public enum EventAction: Equatable, Sendable {
    case activatePath(String)
    case activateScene(String)
    case deactivatePath
    case deactivateScene
    case setLayer(Int)
    case setVisibility(Bool)
    case setCoordinate(Coordinate)
}

public struct EventTrace: Equatable, Sendable {
    public let character: CharacterID
    public let event: RuntimeEvent
    public let caller: EventCaller

    public init(character: CharacterID, event: RuntimeEvent, caller: EventCaller) {
        self.character = character
        self.event = event
        self.caller = caller
    }
}

public struct EventRegistration: Equatable, Sendable {
    public let event: RuntimeEvent
    public let caller: EventCaller
    public let action: EventAction

    public init(event: RuntimeEvent, caller: EventCaller, action: EventAction) {
        self.event = event
        self.caller = caller
        self.action = action
    }
}

public struct CharacterState: Equatable, Sendable {
    public let id: CharacterID
    public let inputCoordinate: Coordinate
    public var currentCoordinate: Coordinate
    public var visual: CharacterVisual
    public var visible: Bool
    public var layer: Int
    public var motion: MotionState
    public var animation: AnimationState
    public var events: [EventRegistration]
    public let preexistingForeground: UInt32?
    public let preexistingBackground: UInt32?

    public init(
        id: CharacterID,
        symbol: Character,
        at coordinate: Coordinate,
        visible: Bool,
        layer: Int,
        foreground: UInt32? = nil,
        background: UInt32? = nil
    ) {
        self.id = id
        self.inputCoordinate = coordinate
        self.currentCoordinate = coordinate
        self.visual = .init(symbol: symbol)
        self.visible = visible
        self.layer = layer
        self.motion = .init()
        self.animation = .init()
        self.events = []
        self.preexistingForeground = foreground
        self.preexistingBackground = background
    }

    fileprivate var isActive: Bool {
        motion.activePathID != nil || animation.activeSceneID != nil
    }
}

public enum CharacterGrouping: Sendable {
    case rowsTopToBottom
    case columnsLeftToRight
}

public struct TerminalModel: Sendable {
    public let canvas: Canvas
    public var characters: ContiguousArray<CharacterState> = []

    public init(canvas: Canvas) {
        self.canvas = canvas
    }

    @discardableResult
    public mutating func addCharacter(
        _ symbol: Character,
        at coordinate: Coordinate,
        visible: Bool = true,
        layer: Int = 0,
        foreground: UInt32? = nil,
        background: UInt32? = nil
    ) -> CharacterID {
        let id = CharacterID(rawValue: characters.count)
        characters.append(.init(
            id: id,
            symbol: symbol,
            at: coordinate,
            visible: visible,
            layer: layer,
            foreground: foreground,
            background: background
        ))
        return id
    }

    public func groupedIDs(_ grouping: CharacterGrouping) -> [[CharacterID]] {
        let groups: [(key: Int, ids: [CharacterID])]
        switch grouping {
        case .rowsTopToBottom:
            let rows = Set(characters.map(\.inputCoordinate.row)).sorted(by: >)
            groups = rows.map { row in
                (row, characters.filter { $0.inputCoordinate.row == row }.map(\.id))
            }
        case .columnsLeftToRight:
            let columns = Set(characters.map(\.inputCoordinate.column)).sorted()
            groups = columns.map { column in
                (column, characters.filter { $0.inputCoordinate.column == column }.map(\.id))
            }
        }
        return groups.map(\.ids)
    }
}

public struct AnimationRuntime: Sendable {
    public internal(set) var terminal: TerminalModel
    public let seed: UInt64
    public internal(set) var eventTrace: [EventTrace] = []
    public internal(set) var lastUpdatedIDs: [CharacterID] = []
    public internal(set) var rngRequestTrace: [String] = []
    public internal(set) var rngValueTrace: [UInt64] = []
    public internal(set) var runtimeActionTrace: [RuntimeAction] = []
    public internal(set) var emittedEvents: [EffectEvent] = []
    public var runtimeBuilt = false
    var rng: Xoshiro256PlusPlus
    var composedPaths: [CharacterID: [String: ComposedPath]] = [:]
    var composedMotions: [CharacterID: RuntimeComposedMotion] = [:]
    var composedScenes: [CharacterID: [String: RuntimeComposedScene]] = [:]
    var activeComposedSceneIDs: [CharacterID: String] = [:]
    var completedComposedMetrics: [CharacterID: SceneMetrics] = [:]
    var runtimeActions = RuntimeActions()
    var releasePlans: [ReleasePlan] = []
    var retiredIDs: Set<CharacterID> = []

    public init(canvas: Canvas, seed: UInt64 = 0) {
        terminal = .init(canvas: canvas)
        self.seed = seed
        rng = .init(seed: seed)
    }

    public mutating func nextRandomUInt64() -> UInt64 {
        drawRandom(named: "nextUInt64")
    }

    public mutating func requestRandomUInt64(named name: String) -> UInt64 {
        drawRandom(named: name)
    }

    @discardableResult
    public mutating func addCharacter(
        _ symbol: Character,
        at coordinate: Coordinate,
        visible: Bool = true,
        layer: Int = 0,
        foreground: UInt32? = nil,
        background: UInt32? = nil
    ) -> CharacterID {
        terminal.addCharacter(
            symbol,
            at: coordinate,
            visible: visible,
            layer: layer,
            foreground: foreground,
            background: background
        )
    }

    public func character(_ id: CharacterID) -> CharacterState {
        terminal.characters[id.rawValue]
    }

    public mutating func setVisibility(_ id: CharacterID, _ visible: Bool) {
        terminal.characters[id.rawValue].visible = visible
    }

    public mutating func setLayer(_ id: CharacterID, _ layer: Int) {
        terminal.characters[id.rawValue].layer = layer
    }

    public mutating func addPath(_ id: CharacterID, _ path: MotionPath) {
        precondition(!terminal.characters[id.rawValue].motion.paths.contains(where: { $0.id == path.id }), "duplicate path id")
        terminal.characters[id.rawValue].motion.paths.append(path)
    }

    public mutating func addScene(_ id: CharacterID, _ scene: AnimationScene) {
        precondition(!terminal.characters[id.rawValue].animation.scenes.contains(where: { $0.id == scene.id }), "duplicate scene id")
        terminal.characters[id.rawValue].animation.scenes.append(scene)
    }

    public mutating func register(_ id: CharacterID, event: RuntimeEvent, caller: EventCaller, action: EventAction) {
        let registration = EventRegistration(event: event, caller: caller, action: action)
        precondition(!terminal.characters[id.rawValue].events.contains(registration), "duplicate event registration")
        terminal.characters[id.rawValue].events.append(registration)
    }

    public mutating func activatePath(_ id: CharacterID, named name: String) {
        guard terminal.characters[id.rawValue].motion.paths.contains(where: { $0.id == name }) else {
            preconditionFailure("path not found")
        }
        terminal.characters[id.rawValue].motion.activePathID = name
        terminal.characters[id.rawValue].motion.progress = 0
        terminal.characters[id.rawValue].motion.holdingTicksRemaining = 0
        fire(id, event: .pathActivated, caller: .path(name))
    }

    public mutating func activateScene(_ id: CharacterID, named name: String) {
        guard let scene = terminal.characters[id.rawValue].animation.scenes.first(where: { $0.id == name }) else {
            preconditionFailure("scene not found")
        }
        terminal.characters[id.rawValue].animation.activeSceneID = name
        terminal.characters[id.rawValue].animation.frameIndex = 0
        terminal.characters[id.rawValue].animation.ticksRemaining = scene.frames[0].duration
        fire(id, event: .sceneActivated, caller: .scene(name))
    }

    @discardableResult
    public mutating func update() -> TickStatus {
        releaseScheduledCharacters()
        lastUpdatedIDs = terminal.characters.compactMap { character in
            character.isActive || composedMotions[character.id] != nil || activeComposedSceneIDs[character.id] != nil
                ? character.id
                : nil
        }
        for id in lastUpdatedIDs {
            stepMotion(id)
            stepAnimation(id)
            stepComposedMotion(id)
            stepComposedScene(id)
        }
        return terminal.characters.contains { character in
            character.isActive || composedMotions[character.id] != nil || activeComposedSceneIDs[character.id] != nil
        } ? .running : .complete
    }

    @discardableResult
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        let status = update()
        render(into: &frame)
        return status
    }

    public func render(into frame: inout Frame) {
        precondition(frame.columns == terminal.canvas.columns && frame.rows == terminal.canvas.rows, "frame dimensions must match canvas")
        frame.withMutableCells { cells in
            for index in cells.indices {
                cells[index] = .blank
            }
        }
        var winners: [Int: CharacterState] = [:]
        for character in terminal.characters where character.visible {
            let coordinate = character.currentCoordinate
            guard (1...frame.columns).contains(coordinate.column), (1...frame.rows).contains(coordinate.row) else { continue }
            let index = (frame.rows - coordinate.row) * frame.columns + (coordinate.column - 1)
            if let current = winners[index], (current.layer, current.id) >= (character.layer, character.id) {
                continue
            }
            winners[index] = character
        }
        for (index, character) in winners {
            frame.withMutableCells { cells in
                cells[index] = Cell(codepoint: character.visual.codepoint, foreground: character.visual.foreground, background: character.visual.background)
            }
        }
    }

    private mutating func stepMotion(_ id: CharacterID) {
        guard let activeID = terminal.characters[id.rawValue].motion.activePathID,
              let path = terminal.characters[id.rawValue].motion.paths.first(where: { $0.id == activeID })
        else { return }

        if terminal.characters[id.rawValue].motion.holdingTicksRemaining > 0 {
            terminal.characters[id.rawValue].motion.holdingTicksRemaining -= 1
            if terminal.characters[id.rawValue].motion.holdingTicksRemaining == 0 {
                finishPath(id, path: path)
            }
            return
        }

        let start = path.waypoints[0]
        let end = path.waypoints[path.waypoints.count - 1]
        let distance = max(abs(end.column - start.column), abs(end.row - start.row))
        let steps = max(1, Int((Double(distance) / path.speed).rounded()))
        terminal.characters[id.rawValue].motion.progress += 1
        let progress = min(terminal.characters[id.rawValue].motion.progress, steps)
        let fraction = Double(progress) / Double(steps)
        let columnDelta = Double(end.column - start.column) * fraction
        let rowDelta = Double(end.row - start.row) * fraction
        terminal.characters[id.rawValue].currentCoordinate = Coordinate(
            column: start.column + Int(columnDelta.rounded()),
            row: start.row + Int(rowDelta.rounded())
        )
        if progress == steps {
            if path.holdTicks > 0 {
                terminal.characters[id.rawValue].motion.holdingTicksRemaining = path.holdTicks
            } else {
                finishPath(id, path: path)
            }
        }
    }

    private mutating func finishPath(_ id: CharacterID, path: MotionPath) {
        if path.loop {
            terminal.characters[id.rawValue].motion.progress = 0
            terminal.characters[id.rawValue].motion.holdingTicksRemaining = 0
        } else {
            terminal.characters[id.rawValue].motion.activePathID = nil
            fire(id, event: .pathComplete, caller: .path(path.id))
        }
    }

    private mutating func stepAnimation(_ id: CharacterID) {
        guard let activeID = terminal.characters[id.rawValue].animation.activeSceneID,
              let scene = terminal.characters[id.rawValue].animation.scenes.first(where: { $0.id == activeID })
        else { return }
        let index = terminal.characters[id.rawValue].animation.frameIndex
        terminal.characters[id.rawValue].visual = scene.frames[index].visual
        terminal.characters[id.rawValue].animation.ticksRemaining -= 1
        guard terminal.characters[id.rawValue].animation.ticksRemaining == 0 else { return }

        let next = index + 1
        if next < scene.frames.count {
            terminal.characters[id.rawValue].animation.frameIndex = next
            terminal.characters[id.rawValue].animation.ticksRemaining = scene.frames[next].duration
            terminal.characters[id.rawValue].visual = scene.frames[next].visual
        } else if scene.loop {
            terminal.characters[id.rawValue].animation.frameIndex = 0
            terminal.characters[id.rawValue].animation.ticksRemaining = scene.frames[0].duration
            terminal.characters[id.rawValue].visual = scene.frames[0].visual
        } else {
            terminal.characters[id.rawValue].animation.activeSceneID = nil
            fire(id, event: .sceneComplete, caller: .scene(scene.id))
        }
    }

    private mutating func fire(_ id: CharacterID, event: RuntimeEvent, caller: EventCaller) {
        eventTrace.append(.init(character: id, event: event, caller: caller))
        let actions = terminal.characters[id.rawValue].events
            .filter { $0.event == event && $0.caller == caller }
            .map(\.action)
        for action in actions {
            apply(action, to: id)
        }
    }

    private mutating func apply(_ action: EventAction, to id: CharacterID) {
        switch action {
        case let .activatePath(name): activatePath(id, named: name)
        case let .activateScene(name): activateScene(id, named: name)
        case .deactivatePath: terminal.characters[id.rawValue].motion.activePathID = nil
        case .deactivateScene: terminal.characters[id.rawValue].animation.activeSceneID = nil
        case let .setLayer(layer): setLayer(id, layer)
        case let .setVisibility(visible): setVisibility(id, visible)
        case let .setCoordinate(coordinate): terminal.characters[id.rawValue].currentCoordinate = coordinate
        }
    }
}
