import Foundation
import Testing
@testable import TTFXCore

private func utf8(_ text: String) -> [UInt8] { Array(text.utf8) }

@Test func ansiControlSequencesMatchRustByteLiterals() {
    #expect(TTFXANSI.decSaveCursor == "\u{1B}7")
    #expect(TTFXANSI.decRestoreCursor == "\u{1B}8")
    #expect(TTFXANSI.hideCursor == "\u{1B}[?25l")
    #expect(TTFXANSI.showCursor == "\u{1B}[?25h")
    #expect(TTFXANSI.resetAll == "\u{1B}[0m")
    #expect(TTFXANSI.moveCursorUp(3) == "\u{1B}[3A")
    #expect(TTFXANSI.moveCursorToColumn(12) == "\u{1B}[12G")
}

@Test func ansiColorSGRSequencesSupport24BitAndXtermModes() {
    #expect(TTFXANSI.foreground(.rgb(0xFF0080)) == "\u{1B}[38;2;255;0;128m")
    #expect(TTFXANSI.background(.rgb(0x123456)) == "\u{1B}[48;2;18;52;86m")
    #expect(TTFXANSI.foreground(.xterm(42)) == "\u{1B}[38;5;42m")
    #expect(TTFXANSI.background(.xterm(196)) == "\u{1B}[48;5;196m")
}

@Test func ansiColorPolicyHonorsNoColorAndXtermRendering() {
    #expect(TTFXANSI.foregroundColor(0xFF0000, options: .init(noColor: true)) == nil)
    #expect(TTFXANSI.foregroundColor(0xFF0000, options: .init(xtermColors: true)) == "\u{1B}[38;5;9m")
    #expect(TTFXANSI.backgroundColor(0x0000FF, options: .init(xtermColors: true)) == "\u{1B}[48;5;12m")
}

@Test func frameRendererEmitsTopRowFirstWithExactFormattedCellBytes() throws {
    var frame = try Frame(columns: 2, rows: 2)
    frame[column: 1, row: 2] = Cell(codepoint: 65, foreground: 0xFF0000, background: 0)
    frame[column: 2, row: 2] = Cell(codepoint: 66, foreground: 0, background: 0x0000FF)
    frame[column: 1, row: 1] = Cell(codepoint: 0x1F642, foreground: 0, background: 0)

    let rendered = TTFXANSIRenderer().render(frame)

    #expect(utf8(rendered) == utf8("\u{1B}[38;2;255;0;0mA\u{1B}[0m\u{1B}[48;2;0;0;255mB\u{1B}[0m\n🙂 "))
}

@Test func frameRendererCanSuppressColorOrUseXtermColorBytes() throws {
    var frame = try Frame(columns: 1, rows: 1)
    frame[column: 1, row: 1] = Cell(codepoint: 90, foreground: 0xFF0000, background: 0x0000FF)

    #expect(TTFXANSIRenderer(options: .init(noColor: true)).render(frame) == "Z")
    #expect(TTFXANSIRenderer(options: .init(xtermColors: true)).render(frame) == "\u{1B}[38;5;9m\u{1B}[48;5;12mZ\u{1B}[0m")
}
