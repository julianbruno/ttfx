import Foundation
import TTFXCore

public struct TTFXRenderableCell: Equatable, Identifiable, Sendable {
    public let id: Int
    public let column: Int
    public let row: Int
    public let codepoint: UInt32
    public let foreground: UInt32
    public let background: UInt32

    public var glyph: String {
        UnicodeScalar(codepoint).map(String.init) ?? "�"
    }

    public var foregroundHex: String { Self.hex(foreground) }
    public var backgroundHex: String { Self.hex(background) }

    public init(id: Int, column: Int, row: Int, codepoint: UInt32, foreground: UInt32, background: UInt32) {
        self.id = id
        self.column = column
        self.row = row
        self.codepoint = codepoint
        self.foreground = foreground
        self.background = background
    }

    private static func hex(_ value: UInt32) -> String {
        let clamped = value & 0x00ff_ffff
        return String(format: "#%06X", clamped)
    }
}

public struct TTFXFrameSnapshot: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let cells: [TTFXRenderableCell]
    public let storageCapacity: Int

    public init(frame: Frame) {
        self.columns = frame.columns
        self.rows = frame.rows
        self.storageCapacity = frame.storageCapacity
        var mapped: [TTFXRenderableCell] = []
        mapped.reserveCapacity(frame.columns * frame.rows)
        var id = 0
        for row in stride(from: frame.rows, through: 1, by: -1) {
            for column in 1...frame.columns {
                let cell = frame[column: column, row: row]
                mapped.append(
                    TTFXRenderableCell(
                        id: id,
                        column: column,
                        row: row,
                        codepoint: cell.codepoint,
                        foreground: cell.foreground,
                        background: cell.background
                    )
                )
                id += 1
            }
        }
        self.cells = mapped
    }

    public var visibleTextLines: [String] {
        var lines: [String] = []
        lines.reserveCapacity(rows)
        for rowIndex in 0..<rows {
            let start = rowIndex * columns
            let end = start + columns
            lines.append(cells[start..<end].map(\.glyph).joined())
        }
        return lines
    }
}
