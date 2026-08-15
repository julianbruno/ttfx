import Testing
@testable import TTFXCore

@Test func cellUsesThreeWordsAndFrameMutatesInPlace() throws {
    let painted = Cell(codepoint: 65, foreground: 0x11223344, background: 0x55667788)
    var frame = try Frame(columns: 2, rows: 2, fill: .blank)

    frame[column: 2, row: 1] = painted

    #expect(MemoryLayout<Cell>.size == 12)
    #expect(frame.cells.count == 4)
    #expect(frame[column: 2, row: 1] == painted)
    #expect(frame[column: 1, row: 2] == .blank)
}

@Test func canvasIngestsUnicodeScalarsInBottomUpCoordinates() throws {
    let canvas = try Canvas(columns: 4, rows: 3)
    let input = canvas.ingest("A\n🙂B")

    #expect(input.scalars == [65, 0x1F642, 66])
    #expect(input.positions == [
        InputPosition(column: 1, row: 2),
        InputPosition(column: 1, row: 1),
        InputPosition(column: 2, row: 1),
    ])
}

@Test func effectProtocolHasDeterministicConstructionAndCompletionStatus() throws {
    struct CompleteImmediately: Effect {
        init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {}

        mutating func tick(into frame: inout Frame) -> TickStatus {
            .complete
        }
    }

    let canvas = try Canvas(columns: 1, rows: 1)
    var frame = try Frame(columns: 1, rows: 1, fill: .blank)
    var effect = CompleteImmediately(
        configuration: .init(),
        canvas: canvas,
        input: canvas.ingest("x"),
        seed: 42
    )

    #expect(effect.tick(into: &frame) == .complete)
}
