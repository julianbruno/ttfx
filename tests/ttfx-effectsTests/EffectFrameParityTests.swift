import Foundation
import Testing
import TTFXCore
import TTFXEffects

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func oracleFrames(named effect: String) throws -> [Data] {
    let url = repositoryRoot().appendingPathComponent("tests/fixtures/effects/\(effect).frames")
    return try FrameDumpDecoder.decode(Data(contentsOf: url))
}

private func terminalBytes(for frame: Frame) -> Data {
    var output = Data()
    for row in stride(from: frame.rows, through: 1, by: -1) {
        for column in 1...frame.columns {
            let cell = frame[column: column, row: row]
            if cell.foreground != 0 {
                let red = cell.foreground >> 16
                let green = (cell.foreground >> 8) & 0xFF
                let blue = cell.foreground & 0xFF
                output.append(Data("\u{1B}[38;2;\(red);\(green);\(blue)m".utf8))
            }
            output.append(Data(String(UnicodeScalar(cell.codepoint)!).utf8))
            if cell.foreground != 0 {
                output.append(Data("\u{1B}[0m".utf8))
            }
        }
        if row != 1 { output.append(10) }
    }
    return output
}

private func visibleGrid(for frame: Frame) -> String {
    (1...frame.rows).reversed().map { row in
        (1...frame.columns).map { column in
            String(UnicodeScalar(frame[column: column, row: row].codepoint)!)
        }.joined()
    }.joined(separator: "\\n")
}

private struct FrameParityResult {
    let finalStatus: TickStatus
    let firstCompletionTick: Int?
}

private func assertFrameParity<E: Effect>(
    _ effect: E,
    expectedFrames: [Data],
    canvas: Canvas,
    name: String
) throws -> FrameParityResult {
    var effect = effect
    var status = TickStatus.running
    var firstCompletionTick: Int?
    for (tick, expected) in expectedFrames.enumerated() {
        var frame = try Frame(columns: canvas.columns, rows: canvas.rows)
        status = effect.tick(into: &frame)
        if status == .complete, firstCompletionTick == nil {
            firstCompletionTick = tick + 1
        }
        if tick + 1 < expectedFrames.count {
            #expect(status == .running, "\(name) completed at tick \(tick + 1) before Rust emitted frame \(expectedFrames.count)")
        }
        #expect(
            terminalBytes(for: frame) == expected,
            "\(name) first mismatch at tick \(tick)\\nactual:\\n\(visibleGrid(for: frame))\\nANSI:\\n\(String(decoding: terminalBytes(for: frame), as: UTF8.self))"
        )
    }
    return .init(finalStatus: status, firstCompletionTick: firstCompletionTick)
}

private func assertFixtureParity<E: Effect>(_ effect: E, named name: String) throws -> FrameParityResult {
    let canvas = try Canvas(columns: 12, rows: 6)
    return try assertFrameParity(effect, expectedFrames: try oracleFrames(named: name), canvas: canvas, name: name)
}

@Suite(.serialized)
struct EffectFrameParityTests {
@Test func printEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        PrintEffect(configuration: .init(text: "Swift\nTTE", seed: 42), canvas: canvas, input: canvas.ingest("Swift\nTTE"), seed: 42),
        named: "print"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames; the independent Rust run proves completion.")
    #expect(status.firstCompletionTick == nil)
}

@Test func printEffectMatchesAnIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "Hi\nZ"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "40",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "print"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 24)
    let status = try assertFrameParity(
        PrintEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "print independent Rust run"
    )
    #expect(status.finalStatus == .complete)
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func slideEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        SlideEffect(configuration: .init(text: "Swift\nTTE", seed: 42), canvas: canvas, input: canvas.ingest("Swift\nTTE"), seed: 42),
        named: "slide"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames; the independent Rust run proves completion.")
    #expect(status.firstCompletionTick == nil)
}

@Test func slideEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "ACE\nB"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "100",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "slide", "--movement-speed", "1.3", "--grouping", "diagonal",
            "--gap", "1", "--merge", "--movement-easing", "out_sine", "--final-gradient-stops",
            "112233", "445566", "--final-gradient-steps", "4", "--final-gradient-frames", "2",
            "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        SlideEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            slideConfiguration: .init(
                movementSpeed: 1.3,
                grouping: .diagonal,
                gap: 1,
                merge: true,
                movementEasing: .outSine,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [4],
                finalGradientFrames: 2,
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "slide configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured slide frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func wipeEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        WipeEffect(
            configuration: .init(text: "Swift\nTTE", seed: 42),
            canvas: canvas,
            input: canvas.ingest("Swift\nTTE"),
            seed: 42,
            wipeConfiguration: .init(
                easing: .outExpo,
                finalGradientSteps: [1],
                finalGradientFrames: 1
            )
        ),
        named: "wipe"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames")
    #expect(status.firstCompletionTick == nil)
}

@Test func wipeEffectMatchesAResettingIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nCDE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "300",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "wipe", "--wipe-direction", "diagonal_bottom_right_to_top_left",
            "--wipe-delay", "1", "--wipe-ease", "out_bounce", "--final-gradient-stops",
            "112233", "445566", "--final-gradient-steps", "2", "--final-gradient-frames", "2",
            "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    let status = try assertFrameParity(
        WipeEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            wipeConfiguration: .init(
                direction: .diagonalBottomRightToTopLeft,
                delay: 1,
                easing: .outBounce,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 2,
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "wipe resetting independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured wipe frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func wipeEffectMatchesAnOutsideToCenterRustRun() throws {
    let canvas = try Canvas(columns: 6, rows: 4)
    let input = "A\nBC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "150",
            "--seed", "11", "--ignore-terminal-dimensions", "--canvas-width", "6",
            "--canvas-height", "4", "wipe", "--wipe-direction", "outside_to_center",
            "--wipe-ease", "out_expo", "--final-gradient-stops", "223344", "556677",
            "--final-gradient-steps", "1", "--final-gradient-frames", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    let status = try assertFrameParity(
        WipeEffect(
            configuration: .init(text: input, seed: 11),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 11,
            wipeConfiguration: .init(
                direction: .outsideToCenter,
                easing: .outExpo,
                finalGradientStops: [Color(hex: "223344"), Color(hex: "556677")],
                finalGradientSteps: [1],
                finalGradientFrames: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "wipe outside-to-center Rust run"
    )
    #expect(status.finalStatus == .complete)
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func expandEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        ExpandEffect(configuration: .init(text: "Swift\nTTE", seed: 42), canvas: canvas, input: canvas.ingest("Swift\nTTE"), seed: 42),
        named: "expand"
    )
    #expect(status.finalStatus == .complete, "The admitted Rust dump ends after 18 frames, below its 32-frame ceiling, so the final fixture tick is the completion boundary.")
    #expect(status.firstCompletionTick == 18)
}

@Test func expandEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 9, rows: 5)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "100",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "9",
            "--canvas-height", "5", "expand", "--expand-easing", "out_sine",
            "--movement-speed", "0.9", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "4", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 6)
    let status = try assertFrameParity(
        ExpandEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            expandConfiguration: .init(
                movementEasing: .outSine,
                movementSpeed: 0.9,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [4],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "expand configured independent Rust run"
    )
    #expect(status.finalStatus == .complete)
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func rainEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        RainEffect(configuration: .init(text: "Swift\nTTE", seed: 42), canvas: canvas, input: canvas.ingest("Swift\nTTE"), seed: 42),
        named: "rain"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames; the independent Rust run proves completion.")
    #expect(status.firstCompletionTick == nil)
}

@Test func rainEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 8, rows: 5)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "200",
            "--seed", "11", "--ignore-terminal-dimensions", "--canvas-width", "8",
            "--canvas-height", "5", "rain", "--rain-colors", "112233", "445566",
            "--movement-speed", "2.0-2.5", "--rain-symbols", "x", "+",
            "--final-gradient-stops", "88aaff", "00ffcc", "--final-gradient-steps", "4",
            "--final-gradient-direction", "horizontal", "--movement-easing", "out_sine"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        RainEffect(
            configuration: .init(text: input, seed: 11),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 11,
            rainConfiguration: .init(
                rainColors: [Color(hex: "112233"), Color(hex: "445566")],
                movementSpeed: (2.0, 2.5),
                rainSymbols: ["x", "+"],
                finalGradientStops: [Color(hex: "88aaff"), Color(hex: "00ffcc")],
                finalGradientSteps: [4],
                finalGradientDirection: .horizontal,
                movementEasing: .outSine
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "rain configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured rain frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func bubblesEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        BubblesEffect(
            configuration: .init(text: "Swift\nTTE", seed: 42),
            canvas: canvas,
            input: canvas.ingest("Swift\nTTE"),
            seed: 42,
            bubblesConfiguration: .init(bubbleSpeed: 3, bubbleDelay: 1)
        ),
        named: "bubbles"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames; the independent Rust run proves completion.")
    #expect(status.firstCompletionTick == nil)
}

@Test func bubblesEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 8, rows: 5)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "200",
            "--seed", "11", "--ignore-terminal-dimensions", "--canvas-width", "8",
            "--canvas-height", "5", "bubbles", "--bubble-speed", "3", "--bubble-delay", "1",
            "--bubble-colors", "112233", "445566", "--pop-color", "ffff00",
            "--movement-easing", "out_sine", "--final-gradient-stops", "88aaff", "00ffcc",
            "--final-gradient-steps", "4", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        BubblesEffect(
            configuration: .init(text: input, seed: 11),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 11,
            bubblesConfiguration: .init(
                bubbleColors: [Color(hex: "112233"), Color(hex: "445566")],
                popColor: Color(hex: "ffff00"),
                bubbleSpeed: 3,
                bubbleDelay: 1,
                movementEasing: .outSine,
                finalGradientStops: [Color(hex: "88aaff"), Color(hex: "00ffcc")],
                finalGradientSteps: [4],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "bubbles configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured bubbles frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func fireworksEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        FireworksEffect(
            configuration: .init(text: "Swift\nTTE", seed: 42),
            canvas: canvas,
            input: canvas.ingest("Swift\nTTE"),
            seed: 42
        ),
        named: "fireworks"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames; the independent Rust run proves completion.")
    #expect(status.firstCompletionTick == nil)
}

@Test func swarmEffectMatchesItsAdmittedRustFrames() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let status = try assertFixtureParity(
        SwarmEffect(
            configuration: .init(text: "Swift\nTTE", seed: 42),
            canvas: canvas,
            input: canvas.ingest("Swift\nTTE"),
            seed: 42,
            swarmConfiguration: .init(swarmSize: 1, swarmCoordination: 1, swarmAreaCountRange: 1...1)
        ),
        named: "swarm"
    )
    #expect(status.finalStatus == .running, "The admitted fixture is intentionally capped at 32 Rust frames; the independent Rust run proves completion.")
    #expect(status.firstCompletionTick == nil)
}

@Test func swarmEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let input = "Swift\nTTE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "150",
            "--seed", "42", "--ignore-terminal-dimensions", "--canvas-width", "12",
            "--canvas-height", "6", "swarm", "--swarm-size", "1", "--swarm-coordination", "1",
            "--swarm-area-count-range", "1-1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 103)
    let status = try assertFrameParity(
        SwarmEffect(
            configuration: .init(text: input, seed: 42),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 42,
            swarmConfiguration: .init(swarmSize: 1, swarmCoordination: 1, swarmAreaCountRange: 1...1)
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "swarm configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured swarm frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func fireworksEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 8, rows: 5)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "250",
            "--seed", "11", "--ignore-terminal-dimensions", "--canvas-width", "8",
            "--canvas-height", "5", "fireworks", "--launch-delay", "1",
            "--firework-colors", "112233", "445566", "--firework-symbol", "*",
            "--firework-volume", "0.5", "--explode-distance", "0.3",
            "--final-gradient-stops", "88aaff", "00ffcc", "--final-gradient-steps", "4",
            "--final-gradient-direction", "vertical"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        FireworksEffect(
            configuration: .init(text: input, seed: 11),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 11,
            fireworksConfiguration: .init(
                fireworkColors: [Color(hex: "112233"), Color(hex: "445566")],
                fireworkSymbol: "*",
                fireworkVolume: 0.5,
                launchDelay: 1,
                explodeDistance: 0.3,
                finalGradientStops: [Color(hex: "88aaff"), Color(hex: "00ffcc")],
                finalGradientSteps: [4],
                finalGradientDirection: .vertical
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "fireworks configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured fireworks frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}
}
