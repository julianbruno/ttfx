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

    init(scalars: ContiguousArray<UInt32>, positions: ContiguousArray<InputPosition>) {
        self.scalars = scalars
        self.positions = positions
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
        scalars.reserveCapacity(text.unicodeScalars.count)
        positions.reserveCapacity(text.unicodeScalars.count)

        for (lineIndex, line) in lines.enumerated() {
            let row = lines.count - lineIndex
            for (columnIndex, scalar) in line.unicodeScalars.enumerated() {
                scalars.append(scalar.value)
                positions.append(InputPosition(column: columnIndex + 1, row: row))
            }
        }
        return InputText(scalars: scalars, positions: positions)
    }
}

public struct EffectConfiguration: Equatable, Sendable {
    public let text: String
    public let seed: UInt64

    public init(text: String = "", seed: UInt64 = 0) {
        self.text = text
        self.seed = seed
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
