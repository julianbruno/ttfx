public struct EffectEvent: Equatable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public enum RuntimeAction: Equatable, Sendable {
    case activatePath(String)
    case activateScene(String)
    case setLayer(Int)
    case setVisibility(Bool)
    case setCoordinate(Coordinate)
    case emit(EffectEvent)

    public var description: String {
        switch self {
        case let .activatePath(path): "activatePath:\(path)"
        case let .activateScene(scene): "activateScene:\(scene)"
        case let .setLayer(layer): "setLayer:\(layer)"
        case let .setVisibility(visible): "setVisibility:\(visible)"
        case let .setCoordinate(coordinate): "setCoordinate:\(coordinate.column),\(coordinate.row)"
        case let .emit(event): "emit:\(event.name)"
        }
    }
}

public struct RuntimeActions: Sendable {
    private var entries: [(CharacterID, RuntimeEvent, EventCaller, RuntimeAction)] = []

    public init() {}

    public mutating func register(_ id: CharacterID, event: RuntimeEvent, caller: EventCaller, action: RuntimeAction) {
        entries.append((id, event, caller, action))
    }

    public func dispatch(_ id: CharacterID, event: RuntimeEvent, caller: EventCaller, perform: (RuntimeAction) -> [RuntimeAction]) -> [RuntimeAction] {
        actions(for: id, event: event, caller: caller)
            .flatMap { action in [action] + perform(action) }
    }

    public func actions(for id: CharacterID, event: RuntimeEvent, caller: EventCaller) -> [RuntimeAction] {
        entries
            .filter { $0.0 == id && $0.1 == event && $0.2 == caller }
            .map(\.3)
    }

    public func drainChain(_ id: CharacterID, startingAt path: String) -> [RuntimeAction] {
        var caller = path
        var trace: [RuntimeAction] = []
        while true {
            let actions = entries
                .filter { $0.0 == id && $0.1 == .pathComplete && $0.2 == .path(caller) }
                .map(\.3)
            guard !actions.isEmpty else { return trace }
            trace.append(contentsOf: actions)
            guard let next = actions.compactMap({ action -> String? in
                guard case let .activatePath(path) = action else { return nil }
                return path
            }).first else { return trace }
            caller = next
        }
    }
}
