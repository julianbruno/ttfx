import Foundation
import Testing
import TTFXCore
import TTFXEffects
@testable import TTFXCLI

@Suite struct NativeTerminalPolicyTests {
    @Test func resizeRNGContinuesCurrentDraws() {
        var oracle = Xoshiro256PlusPlus(seed: 42)
        let stream = RNGContinuation(oracle)
        let configuration = EffectConfiguration(seed: 42, rngContinuation: stream, clock: nil)
        var firstEffect = configuration.makeRNG(seed: 42)
        for _ in 0..<17 { let actual = firstEffect.nextUInt64(); let expected = oracle.nextUInt64(); #expect(actual == expected) }
        #expect(stream.snapshot() == oracle)
        var rebuiltEffect = configuration.makeRNG(seed: 42)
        let actual = rebuiltEffect.nextUInt64(); let expected = oracle.nextUInt64(); #expect(actual == expected)
    }
    @Test func realClockDoesNotAdvanceFromTickCount() throws {
        let canvas = try Canvas(columns: 8, rows: 4)
        let configuration = EffectConfiguration(text: "Clock", seed: 42, frameRate: 60, clock: EffectClock(now: { 0 }))
        var effect = MatrixEffect(configuration: configuration, canvas: canvas, input: canvas.ingest("Clock"), seed: 42)
        var status = TickStatus.running
        for _ in 0..<2_000 {
            var frame = try Frame(columns: 8, rows: 4)
            status = effect.tick(into: &frame)
        }
        #expect(status == .running)
    }
    @Test func dimensionsHonorPartialOverrides() {
        let native = TerminalDimensions(columns: 120, rows: 40)
        #expect(TerminalDimensions.resolve(environment: ["COLUMNS": "77"], native: native) == TerminalDimensions(columns: 77, rows: 40))
        #expect(TerminalDimensions.resolve(environment: ["LINES": "bad"], native: nil) == TerminalDimensions(columns: 80, rows: 24))
    }
    @Test func resizeSettlesOnlyAfterQuietWindow() {
        var resize = SettledResize()
        do { let value = resize.poll(.init(columns: 80, rows: 24), now: 0); #expect(!value) }
        do { let value = resize.poll(.init(columns: 81, rows: 24), now: 0.01); #expect(!value) }
        do { let value = resize.poll(.init(columns: 82, rows: 24), now: 0.04); #expect(!value) }
        do { let value = resize.poll(.init(columns: 82, rows: 24), now: 0.08); #expect(!value) }
        do { let value = resize.poll(.init(columns: 82, rows: 24), now: 0.10); #expect(value) }
        do { let value = resize.poll(.init(columns: 82, rows: 24), now: 1); #expect(!value) }
    }
}
