import Testing
@testable import TTFXCore

private struct NoopEffect: Effect {
    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {}

    mutating func tick(into frame: inout Frame) -> TickStatus {
        .complete
    }
}

@Test func effectEngineInitializesDeterministicallyFromTextCanvasAndSeed() throws {
    let configuration = EffectConfiguration(text: "A\n🙂", seed: 42)
    let canvas = try Canvas(columns: 4, rows: 3)
    let first = try EffectEngine<NoopEffect>(configuration: configuration, canvas: canvas)
    let second = try EffectEngine<NoopEffect>(configuration: configuration, canvas: canvas)

    #expect(first.configuration == configuration)
    #expect(first.input == second.input)
    #expect(first.input.scalars == [65, 0x1F642])
    #expect(first.input.positions == [
        .init(column: 1, row: 2),
        .init(column: 1, row: 1),
    ])
    #expect(first.frame.cells.count == 12)
    #expect(first.status == .running)
}

@Test func effectEnginePreparesEmptyInputWithoutPerTickStringState() throws {
    let engine = try EffectEngine<NoopEffect>(
        configuration: .init(text: "", seed: 7),
        canvas: .init(columns: 1, rows: 1)
    )

    #expect(engine.input.scalars.isEmpty)
    #expect(engine.input.positions.isEmpty)
    #expect(engine.frame[column: 1, row: 1] == .blank)
}
