public enum TTFXANSI {
    public static let decSaveCursor = "\u{1B}7"
    public static let decRestoreCursor = "\u{1B}8"
    public static let hideCursor = "\u{1B}[?25l"
    public static let showCursor = "\u{1B}[?25h"
    public static let resetAll = "\u{1B}[0m"
    public static let clearToEndOfScreen = "\u{1B}[0J"

    public static func moveCursorUp(_ rows: Int) -> String {
        "\u{1B}[\(rows)A"
    }

    public static func moveCursorToColumn(_ column: Int) -> String {
        "\u{1B}[\(column)G"
    }

    public static func foreground(_ color: ANSIColorCode) -> String {
        sgr(color, location: 38)
    }

    public static func background(_ color: ANSIColorCode) -> String {
        sgr(color, location: 48)
    }

    public static func foregroundColor(_ rgb: UInt32, options: TTFXANSIRenderOptions = .init()) -> String? {
        color(rgb, location: 38, options: options)
    }

    public static func backgroundColor(_ rgb: UInt32, options: TTFXANSIRenderOptions = .init()) -> String? {
        color(rgb, location: 48, options: options)
    }

    private static func color(_ rgb: UInt32, location: Int, options: TTFXANSIRenderOptions) -> String? {
        guard rgb != 0, !options.noColor else { return nil }
        if options.xtermColors {
            return sgr(.xterm(Xterm256.closestCode(to: rgb)), location: location)
        }
        return sgr(.rgb(rgb), location: location)
    }

    private static func sgr(_ color: ANSIColorCode, location: Int) -> String {
        switch color {
        case let .rgb(rgb):
            let channels = RGBChannels(rgb)
            return "\u{1B}[\(location);2;\(channels.r);\(channels.g);\(channels.b)m"
        case let .xterm(code):
            return "\u{1B}[\(location);5;\(code)m"
        }
    }
}

public enum ANSIColorCode: Equatable, Sendable {
    case rgb(UInt32)
    case xterm(UInt8)
}

public struct TTFXANSIRenderOptions: Equatable, Sendable {
    public var noColor: Bool
    public var xtermColors: Bool

    public init(noColor: Bool = false, xtermColors: Bool = false) {
        self.noColor = noColor
        self.xtermColors = xtermColors
    }
}

public struct TTFXANSIRenderer: Sendable {
    public var options: TTFXANSIRenderOptions

    public init(options: TTFXANSIRenderOptions = .init()) {
        self.options = options
    }

    public func render(_ frame: Frame) -> String {
        var output = String()
        output.reserveCapacity(frame.columns * frame.rows)
        for row in stride(from: frame.rows, through: 1, by: -1) {
            if row < frame.rows { output.append("\n") }
            for column in 1...frame.columns {
                append(frame[column: column, row: row], to: &output)
            }
        }
        return output
    }

    private func append(_ cell: Cell, to output: inout String) {
        var styled = false
        if let foreground = TTFXANSI.foregroundColor(cell.foreground, options: options) {
            output.append(foreground)
            styled = true
        }
        if let background = TTFXANSI.backgroundColor(cell.background, options: options) {
            output.append(background)
            styled = true
        }
        output.append(Self.scalarString(cell.codepoint))
        if styled {
            output.append(TTFXANSI.resetAll)
        }
    }

    private static func scalarString(_ codepoint: UInt32) -> String {
        guard let scalar = UnicodeScalar(codepoint) else { return " " }
        return String(scalar)
    }
}

private struct RGBChannels {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    init(_ rgb: UInt32) {
        r = UInt8((rgb >> 16) & 0xFF)
        g = UInt8((rgb >> 8) & 0xFF)
        b = UInt8(rgb & 0xFF)
    }
}

public enum Xterm256 {
    private static let basicPalette: [(UInt8, UInt8, UInt8)] = [
        (0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0),
        (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
        (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0),
        (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
    ]

    private static let cubeLevels: [UInt8] = [0, 95, 135, 175, 215, 255]

    public static func closestCode(to rgb: UInt32) -> UInt8 {
        let channels = RGBChannels(rgb)
        var bestCode: UInt8 = 0
        var bestDiff = Int.max
        for code in 0...255 {
            let candidate = color(for: UInt8(code))
            let diff = abs(Int(channels.r) - Int(candidate.0))
                + abs(Int(channels.g) - Int(candidate.1))
                + abs(Int(channels.b) - Int(candidate.2))
            if diff < bestDiff {
                bestDiff = diff
                bestCode = UInt8(code)
            }
        }
        return bestCode
    }

    private static func color(for code: UInt8) -> (UInt8, UInt8, UInt8) {
        if code < 16 { return basicPalette[Int(code)] }
        if code < 232 {
            let index = Int(code) - 16
            return (
                cubeLevels[index / 36],
                cubeLevels[(index / 6) % 6],
                cubeLevels[index % 6]
            )
        }
        let level = UInt8(8 + 10 * (Int(code) - 232))
        return (level, level, level)
    }
}
