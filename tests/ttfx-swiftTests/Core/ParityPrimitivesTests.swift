import Testing
@testable import TTFXCore

@Test func xoshiroSequenceMatchesThePinnedParityShim() {
    var rng = Xoshiro256PlusPlus(seed: 42)
    let values = (0..<5).map { _ in rng.nextUInt64() }

    #expect(values == [
        15_021_278_609_987_233_951,
        5_881_210_131_331_364_753,
        18_149_643_915_985_481_100,
        12_933_668_939_759_105_464,
        14_637_574_242_682_825_331,
    ])
}

@Test func pythonCompatibleMathAndGeometryPreserveQuirks() {
    #expect(PyCompat.roundHalfEven(2.5) == 2)
    #expect(PyCompat.roundHalfEven(-1.5) == -2)
    #expect(PyCompat.floorDivide(7, -2) == -4)
    #expect(Geometry.coordinatesInRectangle(center: .init(column: 3, row: 4), distance: 1) == [
        .init(column: 2, row: 3), .init(column: 2, row: 4), .init(column: 2, row: 5),
        .init(column: 3, row: 3), .init(column: 3, row: 4), .init(column: 3, row: 5),
        .init(column: 4, row: 3), .init(column: 4, row: 4), .init(column: 4, row: 5),
    ])
    #expect(Geometry.coordinateOnLine(from: .init(column: 0, row: 0), to: .init(column: 5, row: 3), t: 0.5) == .init(column: 2, row: 2))
}

@Test func gradientsUseFloorChannelDeltasAndEasingKeepsEndpoints() throws {
    let gradient = try Gradient(stops: [.init(hex: "ff0000"), .init(hex: "0000ff")], steps: 2)

    #expect(gradient.spectrum.map(\.hex) == ["ff0000", "7f007f", "0000ff"])
    #expect(Easing.inOutSine.value(at: 0) == 0)
    #expect(Easing.inOutSine.value(at: 1) == 1)
}

@Test func gradientMappingsKeepTheRustInsertionOrder() throws {
    let gradient = try Gradient(stops: [.init(hex: "ff0000"), .init(hex: "0000ff")], steps: 1)
    let mapping = try gradient.coordinateColorMapping(
        minRow: 1,
        maxRow: 2,
        minColumn: 1,
        maxColumn: 2,
        direction: .horizontal
    )

    #expect(mapping.entries == [
        .init(coordinate: .init(column: 1, row: 1), color: .init(hex: "ff0000")),
        .init(coordinate: .init(column: 1, row: 2), color: .init(hex: "ff0000")),
        .init(coordinate: .init(column: 2, row: 1), color: .init(hex: "0000ff")),
        .init(coordinate: .init(column: 2, row: 2), color: .init(hex: "0000ff")),
    ])
}
