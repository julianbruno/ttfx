import Foundation
import TTFXCore

struct TerminalDimensions: Equatable {
    var columns: Int
    var rows: Int
    static func resolve(environment: [String: String], native: Self?) -> Self {
        Self(columns: environment["COLUMNS"].flatMap(Int.init) ?? native?.columns ?? 80,
             rows: environment["LINES"].flatMap(Int.init) ?? native?.rows ?? 24)
    }
}

struct TerminalLayout: Equatable {
    var columns: Int
    var rows: Int
    var visibleColumns: Int
    var visibleRows: Int
    var columnOffset: Int
    var rowOffset: Int

    init(text: String, options: TerminalOptions, dimensions: TerminalDimensions) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let inputWidth = lines.map { $0.unicodeScalars.count }.max() ?? 0
        let width = options.canvasWidth > 0 ? options.canvasWidth : options.canvasWidth == 0 ? dimensions.columns
            : options.ignoreTerminalDimensions ? inputWidth : min(inputWidth, dimensions.columns)
        columns = max(1, width)
        let resolvedWidth = columns
        let inputHeight = options.wrapText
            ? lines.reduce(0) { $0 + max(1, ($1.unicodeScalars.count + resolvedWidth - 1) / resolvedWidth) } : lines.count
        let height = options.canvasHeight > 0 ? options.canvasHeight : options.canvasHeight == 0 ? dimensions.rows
            : options.ignoreTerminalDimensions ? lines.count : min(inputHeight, dimensions.rows)
        rows = max(1, height)
        let anchor = options.anchorCanvas
        columnOffset = options.ignoreTerminalDimensions ? 0 : [.s, .n, .center].contains(anchor)
            ? PyCompat.floorDivide(dimensions.columns, 2) - PyCompat.floorDivide(columns, 2)
            : [.se, .e, .ne].contains(anchor) ? dimensions.columns - columns : 0
        rowOffset = options.ignoreTerminalDimensions ? 0 : [.w, .e, .center].contains(anchor)
            ? PyCompat.floorDivide(dimensions.rows, 2) - PyCompat.floorDivide(rows, 2)
            : [.nw, .n, .ne].contains(anchor) ? dimensions.rows - rows : 0
        visibleColumns = options.ignoreTerminalDimensions ? columns : max(1, min(columns + columnOffset, dimensions.columns))
        visibleRows = options.ignoreTerminalDimensions ? rows : max(1, min(rows + rowOffset, dimensions.rows))
    }

    func project(_ frame: Frame) throws -> Frame {
        var result = try Frame(columns: visibleColumns, rows: visibleRows)
        for row in 1...frame.rows {
            for column in 1...frame.columns {
                let x = column + columnOffset, y = row + rowOffset
                if (1...visibleColumns).contains(x) && (1...visibleRows).contains(y) {
                    result[column: x, row: y] = frame[column: column, row: row]
                }
            }
        }
        return result
    }
}

struct SettledResize {
    private var observed: TerminalDimensions?
    private var seenAt: Double?
    mutating func poll(_ dimensions: TerminalDimensions, now: Double) -> Bool {
        guard let observed else { self.observed = dimensions; return false }
        if observed != dimensions { self.observed = dimensions; seenAt = now; return false }
        guard let seenAt, now - seenAt >= 0.05 else { return false }
        self.seenAt = nil
        return true
    }
}
