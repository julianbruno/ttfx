import Dispatch
import Testing
@testable import TTFXCore

private struct FrameSweepEffect: Effect {
    private var phase: UInt32 = 0

    init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        phase = UInt32(truncatingIfNeeded: seed)
    }

    mutating func tick(into frame: inout Frame) -> TickStatus {
        phase &+= 1
        let columns = frame.columns
        frame.withMutableCells { cells in
            for index in cells.indices {
                cells[index] = Cell(
                    codepoint: 65 &+ (phase % 26),
                    foreground: UInt32(index % columns + 1),
                    background: UInt32(index / columns + 1)
                )
            }
        }
        return .running
    }
}

@Test func preallocatedEngineMaintainsFrameStorageAcrossFiveHundredTicks() throws {
    let configuration = EffectConfiguration(text: "benchmark", seed: 42)
    let canvas = try Canvas(columns: 200, rows: 50)
    var samples: [UInt64] = []
    samples.reserveCapacity(5)

    for _ in 0..<5 {
        var engine = try EffectEngine<FrameSweepEffect>(configuration: configuration, canvas: canvas)
        let initialCapacity = engine.frame.storageCapacity
        let start = DispatchTime.now().uptimeNanoseconds
        let result = engine.run(ticks: 100)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start

        #expect(result.executedTicks == 100)
        #expect(result.status == .running)
        #expect(engine.frame.cells.count == 10_000)
        #expect(engine.frame.storageCapacity == initialCapacity)
        samples.append(elapsed / 100)
    }

    let medianNanoseconds = samples.sorted()[samples.count / 2]
    #expect(medianNanoseconds < 1_000_000)
}
