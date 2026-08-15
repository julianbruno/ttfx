public struct CharacterSeed: Equatable, Sendable {
    public let symbol: Character
    public let coordinate: Coordinate
    public let visible: Bool
    public let layer: Int

    public init(symbol: Character, coordinate: Coordinate, visible: Bool = false, layer: Int = 0) {
        self.symbol = symbol
        self.coordinate = coordinate
        self.visible = visible
        self.layer = layer
    }
}

public enum CharacterOrder: Sendable {
    case rowsTopToBottom
    case columnsLeftToRight
    case diagonalsTopLeftToBottomRight

    public static func groups(in runtime: AnimationRuntime, order: CharacterOrder) -> [[CharacterID]] {
        let characters = runtime.terminal.characters
        switch order {
        case .rowsTopToBottom:
            return grouped(characters, keys: Set(characters.map { $0.inputCoordinate.row }).sorted(by: >)) { $0.inputCoordinate.row }
        case .columnsLeftToRight:
            return grouped(characters, keys: Set(characters.map { $0.inputCoordinate.column }).sorted()) { $0.inputCoordinate.column }
        case .diagonalsTopLeftToBottomRight:
            return grouped(characters, keys: Set(characters.map { $0.inputCoordinate.column + $0.inputCoordinate.row }).sorted()) { $0.inputCoordinate.column + $0.inputCoordinate.row }
        }
    }

    private static func grouped(_ characters: ContiguousArray<CharacterState>, keys: [Int], key: (CharacterState) -> Int) -> [[CharacterID]] {
        keys.map { value in characters.filter { key($0) == value }.map(\.id) }
    }
}

public struct CharacterGroupSequence: Sendable {
    public let seeds: [CharacterSeed]
    public let order: CharacterOrder
    public let groups: [[CharacterID]]

    public init(seeds: [CharacterSeed], order: CharacterOrder) {
        self.seeds = seeds
        self.order = order
        let identifiers = seeds.indices.map(CharacterID.init(rawValue:))
        switch order {
        case .rowsTopToBottom:
            let keys = Set(seeds.map { $0.coordinate.row }).sorted(by: >)
            groups = keys.map { row in identifiers.filter { seeds[$0.rawValue].coordinate.row == row } }
        case .columnsLeftToRight:
            let keys = Set(seeds.map { $0.coordinate.column }).sorted()
            groups = keys.map { column in identifiers.filter { seeds[$0.rawValue].coordinate.column == column } }
        case .diagonalsTopLeftToBottomRight:
            let keys = Set(seeds.map { $0.coordinate.column + $0.coordinate.row }).sorted()
            groups = keys.map { key in identifiers.filter { seeds[$0.rawValue].coordinate.column + seeds[$0.rawValue].coordinate.row == key } }
        }
    }

    @discardableResult
    public func spawn(into runtime: inout AnimationRuntime) -> [CharacterID] {
        seeds.map { runtime.spawn($0.symbol, at: $0.coordinate, visible: $0.visible, layer: $0.layer) }
    }

    public func assign(paths: [ComposedPath]) -> [CharacterID: ComposedPath] {
        precondition(paths.count == seeds.count, "each character requires a distinct path")
        return Dictionary(uniqueKeysWithValues: zip(seeds.indices.map(CharacterID.init(rawValue:)), paths))
    }
}

public struct ReleasePlan: Sendable {
    private var pending: [CharacterID]
    private let delay: Int
    private var remainingDelay: Int

    public init(groups: [[CharacterID]], delay: Int) {
        precondition(delay >= 0, "release delay must not be negative")
        pending = groups.flatMap { $0 }
        self.delay = delay
        remainingDelay = delay
    }

    public mutating func next() -> [CharacterID] {
        guard !pending.isEmpty else { return [] }
        if remainingDelay > 0 {
            remainingDelay -= 1
            return []
        }
        let next = pending.removeFirst()
        remainingDelay = 0
        return [next]
    }

    public var isComplete: Bool {
        pending.isEmpty
    }
}

public extension AnimationRuntime {
    init(canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(canvas: canvas, seed: seed)
        for (scalar, position) in zip(input.scalars, input.positions) {
            let symbol = Character(UnicodeScalar(scalar)!)
            _ = addCharacter(symbol, at: .init(column: position.column, row: position.row), visible: false)
        }
    }

    @discardableResult
    mutating func spawn(_ symbol: Character, at coordinate: Coordinate, visible: Bool = true, layer: Int = 0) -> CharacterID {
        addCharacter(symbol, at: coordinate, visible: visible, layer: layer)
    }
}
