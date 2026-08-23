import Foundation
import Testing
import TTFXCore
import TTFXEffects

private let explicitBlackForegroundSentinel: UInt32 = 0xFFFF_FFFE

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
            if cell.foreground != 0 || cell.background == explicitBlackForegroundSentinel {
                let red = cell.foreground >> 16
                let green = (cell.foreground >> 8) & 0xFF
                let blue = cell.foreground & 0xFF
                output.append(Data("\u{1B}[38;2;\(red);\(green);\(blue)m".utf8))
            }
            output.append(Data(String(UnicodeScalar(cell.codepoint)!).utf8))
            if cell.foreground != 0 || cell.background == explicitBlackForegroundSentinel {
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

@Test func orbittingVolleyEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "orbittingvolley", "--top-launcher-symbol", "T",
            "--right-launcher-symbol", "R", "--bottom-launcher-symbol", "B",
            "--left-launcher-symbol", "L", "--launcher-movement-speed", "1.4",
            "--character-movement-speed", "0.8", "--volley-size", "0.5",
            "--launch-delay", "1", "--character-easing", "in_out_quad",
            "--final-gradient-stops", "112233", "445566", "--final-gradient-steps", "4",
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
        OrbittingVolleyEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            orbittingVolleyConfiguration: .init(
                topLauncherSymbol: "T",
                rightLauncherSymbol: "R",
                bottomLauncherSymbol: "B",
                leftLauncherSymbol: "L",
                launcherMovementSpeed: 1.4,
                characterMovementSpeed: 0.8,
                volleySize: 0.5,
                launchDelay: 1,
                characterEasing: .inOutQuad,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [4],
                finalGradientDirection: .vertical
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "orbittingvolley configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured orbittingvolley frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func beamsEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "50",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "beams", "--beam-delay", "1",
            "--beam-row-speed-range", "20-20", "--beam-column-speed-range", "20-20",
            "--beam-gradient-stops", "ffffff", "00D1FF", "--beam-gradient-steps", "2",
            "--beam-gradient-frames", "1", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1", "--final-wipe-speed", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 38)
    let status = try assertFrameParity(
        BeamsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            beamsConfiguration: .init(
                beamDelay: 1,
                beamRowSpeedRange: 20...20,
                beamColumnSpeedRange: 20...20,
                beamGradientStops: [Color(hex: "ffffff"), Color(hex: "00D1FF")],
                beamGradientSteps: [2],
                beamGradientFrames: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalWipeSpeed: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "beams one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell beams frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func beamsEffectMatchesACompleteTwoCellRowIndependentRustRun() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    let input = "AB"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "2",
            "--canvas-height", "1", "beams", "--beam-delay", "1",
            "--beam-row-speed-range", "20-20", "--beam-column-speed-range", "20-20",
            "--beam-gradient-stops", "ffffff", "00D1FF", "--beam-gradient-steps", "2",
            "--beam-gradient-frames", "1", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1", "--final-wipe-speed", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 39)
    let status = try assertFrameParity(
        BeamsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            beamsConfiguration: .init(
                beamDelay: 1,
                beamRowSpeedRange: 20...20,
                beamColumnSpeedRange: 20...20,
                beamGradientStops: [Color(hex: "ffffff"), Color(hex: "00D1FF")],
                beamGradientSteps: [2],
                beamGradientFrames: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalWipeSpeed: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "beams two-cell row independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) two-cell beams frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func beamsEffectMatchesASevenByFourIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nCDE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "120",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "beams", "--beam-delay", "1",
            "--beam-row-speed-range", "20-20", "--beam-column-speed-range", "20-20",
            "--beam-gradient-stops", "ffffff", "00D1FF", "--beam-gradient-steps", "2",
            "--beam-gradient-frames", "1", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1", "--final-wipe-speed", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 46)
    let status = try assertFrameParity(
        BeamsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            beamsConfiguration: .init(
                beamDelay: 1,
                beamRowSpeedRange: 20...20,
                beamColumnSpeedRange: 20...20,
                beamGradientStops: [Color(hex: "ffffff"), Color(hex: "00D1FF")],
                beamGradientSteps: [2],
                beamGradientFrames: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalWipeSpeed: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "beams 7x4 independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) 7x4 beams frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func laserEtchGroupedPatternMatchesRustDeadBranchRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "5",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "laseretch", "--etch-pattern", "row_top_to_bottom"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 1)
    let status = try assertFrameParity(
        LaserEtchEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            laserEtchConfiguration: .init(etchPattern: .rowTopToBottom)
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "laseretch grouped-pattern Rust dead-branch run"
    )
    #expect(status.finalStatus == .complete)
    #expect(status.firstCompletionTick == 1)
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
@Test func ringsEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "120",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "rings", "--ring-gap", "1", "--spin-duration", "1",
            "--spin-speed", "1-1", "--disperse-duration", "1", "--spin-disperse-cycles", "1",
            "--ring-colors", "ab48ff", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "vertical"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 107)
    let status = try assertFrameParity(
        RingsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            ringsConfiguration: .init(
                ringColors: [Color(hex: "ab48ff")],
                ringGap: 1,
                spinDuration: 1,
                spinSpeed: 1...1,
                disperseDuration: 1,
                spinDisperseCycles: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .vertical
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "rings one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell rings frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func synthGridEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "100",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "synthgrid"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 60)
    let status = try assertFrameParity(
        SynthGridEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "synthgrid one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell synthgrid frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func blackholeEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "600",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "blackhole", "--blackhole-color", "ffffff",
            "--star-colors", "ffcc0d", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 483)
    let status = try assertFrameParity(
        BlackholeEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            blackholeConfiguration: .init(
                blackholeColor: Color(hex: "ffffff"),
                starColors: [Color(hex: "ffcc0d")],
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "blackhole one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell blackhole frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func laserEtchDefaultAlgorithmMatchesBoundedOneCellRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "55",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "laseretch"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 55)
    let status = try assertFrameParity(
        LaserEtchEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "laseretch default one-cell Rust run"
    )
    #expect(status.finalStatus == .running, "Rust default laseretch remains active beyond this bounded ParticlePool/spark slice")
    #expect(status.firstCompletionTick == nil)
}

@Test func beamsEffectMatchesACompleteTwoCellColumnIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 2)
    let input = "A\nB"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "2", "beams", "--beam-delay", "1",
            "--beam-row-speed-range", "20-20", "--beam-column-speed-range", "20-20",
            "--beam-gradient-stops", "ffffff", "00D1FF", "--beam-gradient-steps", "2",
            "--beam-gradient-frames", "1", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1", "--final-wipe-speed", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 38)
    let status = try assertFrameParity(
        BeamsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            beamsConfiguration: .init(
                beamDelay: 1,
                beamRowSpeedRange: 20...20,
                beamColumnSpeedRange: 20...20,
                beamGradientStops: [Color(hex: "ffffff"), Color(hex: "00D1FF")],
                beamGradientSteps: [2],
                beamGradientFrames: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalWipeSpeed: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "beams two-cell column independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) two-cell column beams frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func beamsEffectMatchesACompleteTwoByTwoIndependentRustRun() throws {
    let canvas = try Canvas(columns: 2, rows: 2)
    let input = "AB\nCD"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "2",
            "--canvas-height", "2", "beams", "--beam-delay", "1",
            "--beam-row-speed-range", "20-20", "--beam-column-speed-range", "20-20",
            "--beam-gradient-stops", "ffffff", "00D1FF", "--beam-gradient-steps", "2",
            "--beam-gradient-frames", "1", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1", "--final-wipe-speed", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 39)
    let status = try assertFrameParity(
        BeamsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            beamsConfiguration: .init(
                beamDelay: 1,
                beamRowSpeedRange: 20...20,
                beamColumnSpeedRange: 20...20,
                beamGradientStops: [Color(hex: "ffffff"), Color(hex: "00D1FF")],
                beamGradientSteps: [2],
                beamGradientFrames: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalWipeSpeed: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "beams two-by-two independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) two-by-two beams frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func ringsEffectMatchesACompleteSevenByFourIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nCDE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "260",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "rings", "--ring-gap", "0.25", "--spin-duration", "1",
            "--spin-speed", "1-1", "--disperse-duration", "1", "--spin-disperse-cycles", "1",
            "--ring-colors", "ab48ff", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 194)
    let status = try assertFrameParity(
        RingsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            ringsConfiguration: .init(
                ringColors: [Color(hex: "ab48ff")],
                ringGap: 0.25,
                spinDuration: 1,
                spinSpeed: 1...1,
                disperseDuration: 1,
                spinDisperseCycles: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "rings seven-by-four independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) seven-by-four rings frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func ringsEffectMatchesACompleteThreeByThreeIndependentRustRun() throws {
    let canvas = try Canvas(columns: 3, rows: 3)
    let input = "ABC\nDEF\nGHI"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "220",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "3",
            "--canvas-height", "3", "rings", "--ring-gap", "1", "--spin-duration", "1",
            "--spin-speed", "1-1", "--disperse-duration", "1", "--spin-disperse-cycles", "1",
            "--ring-colors", "ab48ff", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "vertical"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 194)
    let status = try assertFrameParity(
        RingsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            ringsConfiguration: .init(
                ringColors: [Color(hex: "ab48ff")],
                ringGap: 1,
                spinDuration: 1,
                spinSpeed: 1...1,
                disperseDuration: 1,
                spinDisperseCycles: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .vertical
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "rings three-by-three independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) three-by-three rings frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func blackholeEffectMatchesACompleteTwoCellRowIndependentRustRun() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    let input = "AB"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "800",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "2",
            "--canvas-height", "1", "blackhole", "--blackhole-color", "ffffff",
            "--star-colors", "ffcc0d", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 489)
    let status = try assertFrameParity(
        BlackholeEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            blackholeConfiguration: .init(
                blackholeColor: Color(hex: "ffffff"),
                starColors: [Color(hex: "ffcc0d")],
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "blackhole two-cell row independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) two-cell row blackhole frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func laserEtchDefaultAlgorithmMatchesCompleteTwoCellRowRustRun() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    let input = "AB"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "160",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "2",
            "--canvas-height", "1", "laseretch"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 142)
    let status = try assertFrameParity(
        LaserEtchEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "laseretch default two-cell row Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) two-cell default laseretch frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func synthGridEffectMatchesANonBoundedIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nCDE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "300",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "synthgrid", "--grid-gradient-stops", "ffffff", "ffffff",
            "--grid-gradient-steps", "1", "--text-gradient-stops", "112233", "112233",
            "--text-gradient-steps", "1", "--text-generation-symbols", "x", "--max-active-blocks", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 70)
    let status = try assertFrameParity(
        SynthGridEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            synthGridConfiguration: .init(
                gridGradientStops: [Color(hex: "ffffff"), Color(hex: "ffffff")],
                gridGradientSteps: [1],
                textGradientStops: [Color(hex: "112233"), Color(hex: "112233")],
                textGradientSteps: [1],
                textGenerationSymbols: ["x"],
                maxActiveBlocks: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "synthgrid non-bounded independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) non-bounded synthgrid frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func synthGridEffectMatchesACompleteSmallGridIndependentRustRun() throws {
    let canvas = try Canvas(columns: 4, rows: 3)
    let input = "AB\nCD"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "200",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "4",
            "--canvas-height", "3", "synthgrid", "--grid-gradient-stops", "ffffff", "ffffff",
            "--grid-gradient-steps", "1", "--text-gradient-stops", "112233", "112233",
            "--text-gradient-steps", "1", "--text-generation-symbols", "x", "--max-active-blocks", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 68)
    let status = try assertFrameParity(
        SynthGridEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            synthGridConfiguration: .init(
                gridGradientStops: [Color(hex: "ffffff"), Color(hex: "ffffff")],
                gridGradientSteps: [1],
                textGradientStops: [Color(hex: "112233"), Color(hex: "112233")],
                textGradientSteps: [1],
                textGenerationSymbols: ["x"],
                maxActiveBlocks: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "synthgrid small-grid independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) small-grid synthgrid frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func ringsEffectMatchesAFourByTwoIndependentRustRun() throws {
    let canvas = try Canvas(columns: 4, rows: 2)
    let input = "AB\nCD"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "260",
            "--seed", "5", "--ignore-terminal-dimensions", "--canvas-width", "4",
            "--canvas-height", "2", "rings", "--ring-gap", "0.5", "--spin-duration", "1",
            "--spin-speed", "1-1", "--disperse-duration", "1", "--spin-disperse-cycles", "1",
            "--ring-colors", "ab48ff", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 194)
    let status = try assertFrameParity(
        RingsEffect(
            configuration: .init(text: input, seed: 5),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 5,
            ringsConfiguration: .init(
                ringColors: [Color(hex: "ab48ff")],
                ringGap: 0.5,
                spinDuration: 1,
                spinSpeed: 1...1,
                disperseDuration: 1,
                spinDisperseCycles: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "rings four-by-two independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) four-by-two rings frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func beamsEffectMatchesAThreeByThreeIndependentRustRun() throws {
    let canvas = try Canvas(columns: 3, rows: 3)
    let input = "ABC\nDEF\nGHI"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "120",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "3",
            "--canvas-height", "3", "beams", "--beam-delay", "1",
            "--beam-row-speed-range", "20-20", "--beam-column-speed-range", "20-20",
            "--beam-gradient-stops", "ffffff", "00D1FF", "--beam-gradient-steps", "2",
            "--beam-gradient-frames", "1", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1", "--final-wipe-speed", "1"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 45)
    let status = try assertFrameParity(
        BeamsEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            beamsConfiguration: .init(
                beamDelay: 1,
                beamRowSpeedRange: 20...20,
                beamColumnSpeedRange: 20...20,
                beamGradientStops: [Color(hex: "ffffff"), Color(hex: "00D1FF")],
                beamGradientSteps: [2],
                beamGradientFrames: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalWipeSpeed: 1
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "beams 3x3 independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) 3x3 beams frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func blackholeEffectConsumesTenInputCellsBeforeFinalGradient() throws {
    let canvas = try Canvas(columns: 5, rows: 2)
    let input = "ABCDE\nFGHIJ"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "1200",
            "--seed", "3", "--ignore-terminal-dimensions", "--canvas-width", "5",
            "--canvas-height", "2", "blackhole", "--blackhole-color", "ffffff",
            "--star-colors", "ffcc0d", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 521)

    var effect = BlackholeEffect(
        configuration: .init(text: input, seed: 3),
        canvas: canvas,
        input: canvas.ingest(input),
        seed: 3,
        blackholeConfiguration: .init(
            blackholeColor: Color(hex: "ffffff"),
            starColors: [Color(hex: "ffcc0d")],
            finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
            finalGradientSteps: [2],
            finalGradientDirection: .horizontal
        )
    )

    var firstCompletionTick: Int?
    var observedConsumedBlank = false
    var finalBytes = Data()
    for tick in 1...expectedFrames.count {
        var frame = try Frame(columns: canvas.columns, rows: canvas.rows)
        let status = effect.tick(into: &frame)
        if visibleGrid(for: frame) == "     \\n     " { observedConsumedBlank = true }
        if status == .complete, firstCompletionTick == nil { firstCompletionTick = tick }
        finalBytes = terminalBytes(for: frame)
    }

    #expect(observedConsumedBlank, "10-cell blackhole should consume the input into a blank singularity phase before cooling")
    #expect(firstCompletionTick == expectedFrames.count)
    #expect(finalBytes == expectedFrames.last)
}

@Test func synthGridEffectMatchesADefaultPartitionedMultiSymbolIndependentRustRun() throws {
    let canvas = try Canvas(columns: 8, rows: 6)
    let input = "Swift\nTTE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "40",
            "--seed", "42", "--ignore-terminal-dimensions", "--canvas-width", "8",
            "--canvas-height", "6", "synthgrid"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 40)
    let status = try assertFrameParity(
        SynthGridEffect(
            configuration: .init(text: input, seed: 42),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 42
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "synthgrid default partitioned multi-symbol independent Rust run"
    )
    #expect(status.finalStatus == .running, "Rust bounded default partitioned synthgrid run remains active beyond this slice")
    #expect(status.firstCompletionTick == nil)
}

@Test func laserEtchDefaultAlgorithmMatchesFourByThreeRustRun() throws {
    let canvas = try Canvas(columns: 4, rows: 3)
    let input = "ABC\nD"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "300",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "4",
            "--canvas-height", "3", "laseretch"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 148)
    let status = try assertFrameParity(
        LaserEtchEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "laseretch default 4x3 Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) 4x3 default laseretch frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func orbittingVolleyEffectMatchesADefaultLargerIndependentRustRun() throws {
    let canvas = try Canvas(columns: 12, rows: 6)
    let input = "Swift\nTTE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "300",
            "--seed", "42", "--ignore-terminal-dimensions", "--canvas-width", "12",
            "--canvas-height", "6", "orbittingvolley"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 39)
    let status = try assertFrameParity(
        OrbittingVolleyEffect(
            configuration: .init(text: input, seed: 42),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 42
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "orbittingvolley default larger independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) default larger orbittingvolley frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func highlightEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nCDE"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "150",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "highlight", "--highlight-brightness", "1.5",
            "--highlight-direction", "diagonal_bottom_left_to_top_right", "--highlight-width", "2",
            "--final-gradient-stops", "112233", "445566", "--final-gradient-steps", "4",
            "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 117)
    let status = try assertFrameParity(
        HighlightEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            highlightConfiguration: .init(
                highlightBrightness: 1.5,
                highlightDirection: .diagonalBottomLeftToTopRight,
                highlightWidth: 2,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [4],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "highlight configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured highlight frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func middleoutEffectMatchesAConfiguredIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "100",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "middleout", "--expand-direction", "horizontal",
            "--center-movement-speed", "1.0", "--full-movement-speed", "1.0",
            "--center-easing", "out_sine", "--full-easing", "in_out_sine",
            "--starting-color", "112233", "--final-gradient-stops", "445566", "778899",
            "--final-gradient-steps", "3", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        MiddleoutEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            middleoutConfiguration: .init(
                startingColor: Color(hex: "112233"),
                expandDirection: .horizontal,
                centerMovementSpeed: 1.0,
                fullMovementSpeed: 1.0,
                centerEasing: .outSine,
                fullEasing: .inOutSine,
                finalGradientStops: [Color(hex: "445566"), Color(hex: "778899")],
                finalGradientSteps: [3],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "middleout configured independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured middleout frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func wavesEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "waves", "--wave-symbols", "x",
            "--wave-gradient-stops", "ffffff", "--wave-gradient-steps", "1",
            "--wave-count", "1", "--wave-length", "1", "--final-gradient-stops",
            "112233", "445566", "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        WavesEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            wavesConfiguration: .init(
                waveSymbols: ["x"],
                waveGradientStops: [Color(hex: "ffffff")],
                waveGradientSteps: [1],
                waveCount: 1,
                waveLength: 1,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "waves one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell waves frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func matrixEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "120",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "matrix", "--rain-time", "1",
            "--rain-fall-delay-range", "1-1", "--rain-column-delay-range", "1-1",
            "--rain-symbols", "x", "--rain-color-gradient", "112233",
            "--highlight-color", "ffffff", "--symbol-swap-chance", "0.000001",
            "--color-swap-chance", "0.000001", "--resolve-delay", "1",
            "--final-gradient-stops", "445566", "--final-gradient-steps", "1",
            "--final-gradient-frames", "1", "--final-gradient-direction", "vertical"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        MatrixEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            matrixConfiguration: .init(
                highlightColor: Color(hex: "ffffff"),
                rainColorGradient: [Color(hex: "112233")],
                rainSymbols: ["x"],
                rainFallDelayRange: 1...1,
                rainColumnDelayRange: 1...1,
                rainTime: 1,
                symbolSwapChance: 0.000001,
                colorSwapChance: 0.000001,
                resolveDelay: 1,
                finalGradientStops: [Color(hex: "445566")],
                finalGradientSteps: [1],
                finalGradientFrames: 1,
                finalGradientDirection: .vertical
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "matrix one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell matrix frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func burnEffectMatchesACompleteOneCellNoSmokeIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "220",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "burn", "--smoke-chance", "0",
            "--final-gradient-stops", "112233", "445566", "--final-gradient-steps", "2",
            "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 200)
    let status = try assertFrameParity(
        BurnEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            burnConfiguration: .init(
                smokeChance: 0,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "burn one-cell no-smoke independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell no-smoke burn frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func crumbleEffectMatchesABoundedOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "64",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "crumble", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        CrumbleEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            crumbleConfiguration: .init(
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "crumble bounded one-cell independent Rust run"
    )
    #expect(status.finalStatus == .running, "The bounded one-cell Rust run continues beyond this crumble prefix")
    #expect(status.firstCompletionTick == nil)
}

@Test func decryptEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "220",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "decrypt", "--typing-speed", "1",
            "--ciphertext-colors", "00ff00", "--final-gradient-stops", "112233",
            "--final-gradient-steps", "1", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        DecryptEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            decryptConfiguration: .init(
                typingSpeed: 1,
                ciphertextColors: [Color(hex: "00ff00")],
                finalGradientStops: [Color(hex: "112233")],
                finalGradientSteps: [1],
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "decrypt one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell decrypt frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

    @Test func errorCorrectEffectMatchesABoundedTwoCellIndependentRustRun() throws {
        let canvas = try Canvas(columns: 2, rows: 1)
        let input = "AB"
        let result = try ProcessRunner().run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [
                "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "120",
                "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "2",
                "--canvas-height", "1", "errorcorrect", "--error-pairs", "1", "--swap-delay", "1",
                "--movement-speed", "1", "--final-gradient-stops", "112233", "445566",
                "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
            ],
            stdin: Data(input.utf8),
            environment: ProcessInfo.processInfo.environment,
            currentDirectory: repositoryRoot(),
            timeout: 30
        )
        let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
        #expect(expectedFrames.count == 120)
        let status = try assertFrameParity(
            ErrorCorrectEffect(
                configuration: .init(text: input, seed: 1),
                canvas: canvas,
                input: canvas.ingest(input),
                seed: 1,
                errorCorrectConfiguration: .init(
                    errorPairs: 1,
                    swapDelay: 1,
                    movementSpeed: 1,
                    finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                    finalGradientSteps: [2],
                    finalGradientDirection: .horizontal
                )
            ),
            expectedFrames: expectedFrames,
            canvas: canvas,
            name: "errorcorrect bounded two-cell independent Rust run"
        )
        #expect(status.finalStatus == .running, "The bounded two-cell Rust run continues beyond this errorcorrect prefix")
        #expect(status.firstCompletionTick == nil)
    }

@Test func pourEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "pour", "--pour-speed", "1", "--movement-speed-range", "20-20",
            "--gap", "0", "--starting-color", "112233", "--final-gradient-stops", "445566",
            "--final-gradient-steps", "1", "--final-gradient-frames", "1", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        PourEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            pourConfiguration: .init(
                pourSpeed: 1,
                movementSpeedRange: 20...20,
                gap: 0,
                startingColor: Color(hex: "112233"),
                finalGradientStops: [Color(hex: "445566")],
                finalGradientSteps: [1],
                finalGradientFrames: 1,
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "pour one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell pour frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func pourEffectMatchesARightwardTwoCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 2, rows: 1)
    let input = "AB"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "2",
            "--canvas-height", "1", "pour", "--pour-direction", "right", "--pour-speed", "1",
            "--movement-speed-range", "1-1", "--gap", "0", "--starting-color", "112233",
            "--final-gradient-stops", "445566", "778899", "--final-gradient-steps", "2",
            "--final-gradient-frames", "1", "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(!expectedFrames.isEmpty)
    let status = try assertFrameParity(
        PourEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            pourConfiguration: .init(
                pourDirection: .right,
                pourSpeed: 1,
                movementSpeedRange: 1...1,
                gap: 0,
                startingColor: Color(hex: "112233"),
                finalGradientStops: [Color(hex: "445566"), Color(hex: "778899")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "pour rightward two-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) rightward two-cell pour frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func scatteredEffectMatchesACompleteOneCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 1, rows: 1)
    let input = "A"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
            "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
            "--canvas-height", "1", "scattered", "--movement-speed", "1",
            "--movement-easing", "linear", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1",
            "--final-gradient-direction", "horizontal"
        ],
        stdin: Data(input.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: 30
    )
    let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
    #expect(expectedFrames.count == 26)
    let status = try assertFrameParity(
        ScatteredEffect(
            configuration: .init(text: input, seed: 1),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 1,
            scatteredConfiguration: .init(
                movementSpeed: 1,
                movementEasing: .linear,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "scattered one-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell scattered frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

@Test func scatteredEffectMatchesAConfiguredMultiCellIndependentRustRun() throws {
    let canvas = try Canvas(columns: 7, rows: 4)
    let input = "AB\nC"
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [
            "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "120",
            "--seed", "7", "--ignore-terminal-dimensions", "--canvas-width", "7",
            "--canvas-height", "4", "scattered", "--movement-speed", "10",
            "--movement-easing", "linear", "--final-gradient-stops", "112233", "445566",
            "--final-gradient-steps", "2", "--final-gradient-frames", "1",
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
        ScatteredEffect(
            configuration: .init(text: input, seed: 7),
            canvas: canvas,
            input: canvas.ingest(input),
            seed: 7,
            scatteredConfiguration: .init(
                movementSpeed: 10,
                movementEasing: .linear,
                finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                finalGradientSteps: [2],
                finalGradientFrames: 1,
                finalGradientDirection: .horizontal
            )
        ),
        expectedFrames: expectedFrames,
        canvas: canvas,
        name: "scattered configured multi-cell independent Rust run"
    )
    #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) configured scattered frames")
    #expect(status.firstCompletionTick == expectedFrames.count)
}

    @Test func smokeEffectMatchesACompleteOneCellIndependentRustRun() throws {
        let canvas = try Canvas(columns: 1, rows: 1)
        let input = "A"
        let result = try ProcessRunner().run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [
                "cargo", "run", "--quiet", "--", "--parity-dump", "--max-frames", "80",
                "--seed", "1", "--ignore-terminal-dimensions", "--canvas-width", "1",
                "--canvas-height", "1", "smoke", "--smoke-symbols", "x",
                "--smoke-gradient-stops", "ffffff", "--final-gradient-stops", "112233", "445566",
                "--final-gradient-steps", "2", "--final-gradient-direction", "horizontal"
            ],
            stdin: Data(input.utf8),
            environment: ProcessInfo.processInfo.environment,
            currentDirectory: repositoryRoot(),
            timeout: 30
        )
        let expectedFrames = try FrameDumpDecoder.decode(result.stdout)
        #expect(!expectedFrames.isEmpty)
        let status = try assertFrameParity(
            SmokeEffect(
                configuration: .init(text: input, seed: 1),
                canvas: canvas,
                input: canvas.ingest(input),
                seed: 1,
                smokeConfiguration: .init(
                    smokeSymbols: ["x"],
                    smokeGradientStops: [Color(hex: "ffffff")],
                    finalGradientStops: [Color(hex: "112233"), Color(hex: "445566")],
                    finalGradientSteps: [2],
                    finalGradientDirection: .horizontal
                )
            ),
            expectedFrames: expectedFrames,
            canvas: canvas,
            name: "smoke one-cell independent Rust run"
        )
        #expect(status.finalStatus == .complete, "Rust emitted \(expectedFrames.count) one-cell smoke frames")
        #expect(status.firstCompletionTick == expectedFrames.count)
    }

}
