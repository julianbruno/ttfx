import Testing
@testable import TTFXCore

private struct TwoStepEffect: Effect {
    private var step = 0

    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {}

    mutating func tick(into frame: inout Frame) -> TickStatus {
        step += 1
        frame[column: 1, row: 1] = Cell(codepoint: UInt32(64 + step), foreground: 0, background: 0)
        return step == 2 ? .complete : .running
    }
}

private struct ImmediateEffect: Effect {
    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {}

    mutating func tick(into frame: inout Frame) -> TickStatus {
        frame[column: 1, row: 1] = Cell(codepoint: 90, foreground: 0, background: 0)
        return .complete
    }
}

@Test func tickAdvancesAStateMachineAndRetainsItsCompletedFrame() throws {
    var engine = try EffectEngine<TwoStepEffect>(
        configuration: .init(text: "x", seed: 1),
        canvas: .init(columns: 1, rows: 1)
    )

    #expect(engine.tick() == .running)
    #expect(engine.status == .running)
    #expect(engine.frame[column: 1, row: 1].codepoint == 65)
    #expect(engine.tick() == .complete)
    #expect(engine.status == .complete)
    #expect(engine.frame[column: 1, row: 1].codepoint == 66)
    #expect(engine.tick() == .complete)
    #expect(engine.frame[column: 1, row: 1].codepoint == 66)
}

@Test func tickDoesNotInvokeAnEffectAfterAnImmediateCompletion() throws {
    var engine = try EffectEngine<ImmediateEffect>(
        configuration: .init(text: "", seed: 2),
        canvas: .init(columns: 1, rows: 1)
    )

    #expect(engine.tick() == .complete)
    #expect(engine.frame[column: 1, row: 1].codepoint == 90)
    #expect(engine.tick() == .complete)
    #expect(engine.frame[column: 1, row: 1].codepoint == 90)
}
