public let coreModuleIdentifier = "TTFXCore"

public enum CoreError: Error, Equatable, Sendable {
    case invalidDimensions(columns: Int, rows: Int)
}

public struct Cell: Equatable, Sendable {
    public var codepoint: UInt32
    public var foreground: UInt32
    public var background: UInt32

    public init(codepoint: UInt32, foreground: UInt32, background: UInt32) {
        self.codepoint = codepoint
        self.foreground = foreground
        self.background = background
    }

    public static let blank = Cell(codepoint: 32, foreground: 0, background: 0)
}

public struct Frame: Sendable {
    public let columns: Int
    public let rows: Int
    public private(set) var cells: ContiguousArray<Cell>

    public init(columns: Int, rows: Int, fill: Cell = .blank) throws {
        guard columns > 0, rows > 0 else {
            throw CoreError.invalidDimensions(columns: columns, rows: rows)
        }
        self.columns = columns
        self.rows = rows
        self.cells = ContiguousArray(repeating: fill, count: columns * rows)
    }

    public subscript(column column: Int, row row: Int) -> Cell {
        get { cells[offset(column: column, row: row)] }
        set { cells[offset(column: column, row: row)] = newValue }
    }

    public var storageCapacity: Int {
        cells.capacity
    }

    public mutating func withMutableCells<Result>(
        _ body: (inout ContiguousArray<Cell>) throws -> Result
    ) rethrows -> Result {
        try body(&cells)
    }

    private func offset(column: Int, row: Int) -> Int {
        precondition((1...columns).contains(column), "column outside frame")
        precondition((1...rows).contains(row), "row outside frame")
        return (rows - row) * columns + (column - 1)
    }
}

public struct InputPosition: Equatable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

public struct InputText: Equatable, Sendable {
    public let scalars: ContiguousArray<UInt32>
    public let positions: ContiguousArray<InputPosition>
    /// Original terminal arena IDs, including gaps left by unstyled spaces.
    public let characterIDs: ContiguousArray<Int>

    init(scalars: ContiguousArray<UInt32>, positions: ContiguousArray<InputPosition>, characterIDs: ContiguousArray<Int>? = nil) {
        self.scalars = scalars
        self.positions = positions
        self.characterIDs = characterIDs ?? ContiguousArray(scalars.indices)
    }
}

public struct Canvas: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int) throws {
        guard columns > 0, rows > 0 else {
            throw CoreError.invalidDimensions(columns: columns, rows: rows)
        }
        self.columns = columns
        self.rows = rows
    }

    public func ingest(_ text: String) -> InputText {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var scalars = ContiguousArray<UInt32>()
        var positions = ContiguousArray<InputPosition>()
        var characterIDs = ContiguousArray<Int>()
        var arenaID = 0
        scalars.reserveCapacity(text.unicodeScalars.count)
        positions.reserveCapacity(text.unicodeScalars.count)

        for (lineIndex, line) in lines.enumerated() {
            let row = lines.count - lineIndex
            for (columnIndex, scalar) in line.unicodeScalars.enumerated() {
                defer { arenaID += 1 }
                // Rust keeps plain spaces in its arena, but animates them only
                // when an effect explicitly requests fill characters.
                guard scalar.value != 32,
                      columnIndex < columns, (1...rows).contains(row) else { continue }
                scalars.append(scalar.value)
                positions.append(InputPosition(column: columnIndex + 1, row: row))
                characterIDs.append(arenaID)
            }
        }
        return InputText(scalars: scalars, positions: positions, characterIDs: characterIDs)
    }
}

public struct EffectConfiguration: Equatable, Sendable {
    public let text: String
    public let seed: UInt64
    public let frameRate: Int
    public let initialRNG: Xoshiro256PlusPlus?

    public func makeRNG(seed: UInt64) -> Xoshiro256PlusPlus {
        initialRNG ?? Xoshiro256PlusPlus(seed: seed)
    }

    public init(text: String = "", seed: UInt64 = 0, frameRate: Int = 60, initialRNG: Xoshiro256PlusPlus? = nil) {
        precondition(frameRate >= 0, "frame rate must not be negative")
        self.text = text
        self.seed = seed
        self.frameRate = frameRate == 0 ? 60 : frameRate
        self.initialRNG = initialRNG
    }
}

public typealias EffectConfig = EffectConfiguration

public enum TickStatus: Equatable, Sendable {
    case running
    case complete
}

public struct TickRunResult: Equatable, Sendable {
    public let executedTicks: Int
    public let status: TickStatus

    public init(executedTicks: Int, status: TickStatus) {
        self.executedTicks = executedTicks
        self.status = status
    }
}

public protocol Effect {
    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64)
    mutating func tick(into frame: inout Frame) -> TickStatus
}
