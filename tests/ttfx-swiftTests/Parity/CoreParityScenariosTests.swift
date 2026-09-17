import Testing
@testable import TTFXCore

@Test func parityDiagnosticsReportTheFirstDifferingTickCellAndWords() throws {
    let original = Cell(codepoint: 65, foreground: 1, background: 2)
    let changed = Cell(codepoint: 66, foreground: 3, background: 4)
    let expected = try Frame(columns: 2, rows: 2, fill: original)
    var actual = expected
    actual[column: 2, row: 1] = changed

    let mismatch = FrameParity.firstCellMismatch(expected: expected, actual: actual, tick: 7)

    #expect(mismatch == CellMismatch(tick: 7, column: 2, row: 1, expected: original, actual: changed))
}

@Test func coreParityScenariosCoverEmptySmallAndInvalidCanvasInputs() throws {
    let oneCellCanvas = try Canvas(columns: 1, rows: 1)
    let empty = oneCellCanvas.ingest("")
    let overflowing = oneCellCanvas.ingest("AB")

    #expect(empty.scalars.isEmpty)
    #expect(overflowing.scalars == [65])
    #expect(overflowing.positions == [.init(column: 1, row: 1)])
    #expect(throws: CoreError.self) { try Canvas(columns: 0, rows: 1) }
}

@Test func rngIntegerHelpersMatchThePinnedOracleAcrossASecondSeed() {
    var rng = Xoshiro256PlusPlus(seed: 7)
    let values = (0..<5).map { _ in rng.integer(in: -3...3) }

    #expect(values == [-3, -2, 2, 0, 0])
}
