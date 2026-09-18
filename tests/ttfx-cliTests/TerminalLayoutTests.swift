import Foundation
import Testing
import TTFXCore
@testable import TTFXCLI

@Suite(.serialized) struct TerminalLayoutTests {
    @Test func invalidUTF8IsRejected() throws {
        let cli = try TTFXCLI.parse(["--seed", "42", "print"])
        #expect(throws: (any Error).self) { try cli.inputText(standardInput: Data([0xFF])) }
    }
    @Test func zeroCanvasDimensionUsesTerminalFallback() throws {
        let cli = try TTFXCLI.parse(["--seed", "42", "--canvas-width", "0", "--canvas-height", "1", "--frame-rate", "0", "print"])
        let output = try cli.renderOutput(standardInput: Data("Hi".utf8), dimensions: .init(columns: 80, rows: 24))
        #expect(output.starts(with: Data(("\u{1B}[?25l" + String(repeating: " ", count: 80) + "\n\u{1B}7").utf8)))
    }
    @Test func noColorSuppressesForegroundSGR() throws {
        let cli = try TTFXCLI.parse(["--seed", "42", "--no-color", "--frame-rate", "0", "print"])
        let output = try cli.renderOutput(standardInput: Data("Hi".utf8), dimensions: .init(columns: 80, rows: 24))
        #expect(!String(decoding: output, as: UTF8.self).contains("\u{1B}[38;"))
    }
    @Test func inferredWidthCountsUnicodeScalars() throws {
        let cli = try TTFXCLI.parse(["--seed", "42", "--frame-rate", "0", "print"])
        let output = try cli.renderOutput(standardInput: Data("e\u{301}".utf8))
        #expect(output.starts(with: Data("\u{1B}[?25l  \n\u{1B}7".utf8)))
    }
}

extension TerminalLayoutTests {
    @Test func inputAnchorsUseReferenceOddCenterAndNonspaceExtents() throws {
        let canvas = try TTFXCore.Canvas(columns: 5, rows: 5)
        #expect(canvas.ingest("A", wrap: false, anchor: "c").positions.first == TTFXCore.InputPosition(column: 4, row: 4))
        #expect(canvas.ingest("A  ", wrap: false, anchor: "ne").positions.first == TTFXCore.InputPosition(column: 5, row: 5))
    }
    @Test func wrappingPreservesScalarAndArenaOrder() throws {
        let canvas = try TTFXCore.Canvas(columns: 2, rows: 2)
        let input = canvas.ingest("A BC", wrap: true, anchor: "sw")
        #expect(Array(input.scalars) == [65, 66, 67])
        #expect(Array(input.characterIDs) == [0, 2, 3])
        #expect(Array(input.positions) == [.init(column: 1, row: 2), .init(column: 1, row: 1), .init(column: 2, row: 1)])
    }
}
