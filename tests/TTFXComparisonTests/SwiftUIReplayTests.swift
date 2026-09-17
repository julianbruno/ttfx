import Foundation
import Testing
import TTFXCore
import TTFXSwiftUI
@testable import TTFXVideoCapture

@Test @MainActor func swiftUIReplayPreservesBlankCellBackgroundsAndGridCoordinates() throws {
    var frame = try Frame(columns: 3, rows: 2)
    frame[column: 2, row: 2] = Cell(codepoint: 32, foreground: 0, background: 0xff0000)
    frame[column: 3, row: 1] = Cell(codepoint: 32, foreground: 0, background: 0x0000ff)
    let pixels = try TTFXVideoCapture.renderSwiftUIBGRA(snapshot: .init(frame: frame), width: 48, height: 48)
    func pixel(_ x: Int, _ y: Int) -> [UInt8] {
        let offset = (y * 48 + x) * 4
        return Array(pixels[offset..<(offset + 4)])
    }
    #expect(pixel(24, 12) == [0, 0, 255, 255])
    #expect(pixel(40, 36) == [255, 0, 0, 255])
    #expect(pixel(8, 12) == [0, 0, 0, 255])
    #expect(pixel(24, 36) == [0, 0, 0, 255])
}

@Test @MainActor func swiftUIReplayPreservesColoredGlyphsAtRustScaleAndBottomRow() throws {
    var frame = try Frame(columns: 3, rows: 3)
    frame[column: 2, row: 1] = Cell(codepoint: 70, foreground: 0xff0000, background: 0)
    let snapshot = TTFXFrameSnapshot(frame: frame)
    let swift = try TTFXVideoCapture.renderSwiftUIBGRA(snapshot: snapshot, width: 48, height: 72)
    let rust = try ANSIRasterizer(columns: 3, rows: 3).pixels("   \n   \n \u{1b}[38;2;255;0;0mF\u{1b}[0m ")
    func bounds(_ data: Data) -> (Int, Int, Int, Int, Int) {
        var xs: [Int] = [], ys: [Int] = []
        for y in 0..<72 {
            for x in 0..<48 {
                let offset = (y * 48 + x) * 4
                if data[offset + 2] > 80, data[offset + 1] < 20, data[offset] < 20 {
                    xs.append(x); ys.append(y)
                }
            }
        }
        return (xs.min() ?? -1, xs.max() ?? -1, ys.min() ?? -1, ys.max() ?? -1, xs.count)
    }
    let actual = bounds(swift), expected = bounds(rust)
    #expect(actual.4 > 25)
    #expect(abs(actual.0 - expected.0) <= 1)
    #expect(abs(actual.1 - expected.1) <= 1)
    #expect(abs(actual.2 - expected.2) <= 1)
    #expect(abs(actual.3 - expected.3) <= 1)
}

@Test @MainActor func swiftUIReplayMatchesRustRGBAcrossUnicodeCells() throws {
    var frame = try Frame(columns: 3, rows: 1)
    frame[column: 1, row: 1] = Cell(codepoint: 32, foreground: 0, background: 0x112233)
    frame[column: 2, row: 1] = Cell(codepoint: 937, foreground: 0x55cc99, background: 0)
    frame[column: 3, row: 1] = Cell(codepoint: 70, foreground: 0xffffff, background: 0)
    let actual = try TTFXVideoCapture.renderSwiftUIBGRA(snapshot: .init(frame: frame), width: 48, height: 24)
    let expected = try ANSIRasterizer(columns: 3, rows: 1).pixels("\u{1b}[48;2;17;34;51m \u{1b}[0m\u{1b}[38;2;85;204;153mΩ\u{1b}[0mF")
    #expect(Array(actual[0..<4]) == Array(expected[0..<4]))
    // SwiftUI and CoreText can differ in antialiasing, but not glyph metrics or RGB.
    var differing = 0
    for y in 0..<24 {
        for x in 16..<48 {
            let offset = (y * 48 + x) * 4
            if (0..<3).contains(where: { abs(Int(actual[offset + $0]) - Int(expected[offset + $0])) > 20 }) {
                differing += 1
            }
        }
    }
    #expect(differing < 100)
}
