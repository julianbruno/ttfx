import Foundation
import TTFXCore

public struct BeamsEffect: Effect {
    public struct Configuration: Sendable {
        public var beamRowSymbols: [String]
        public var beamColumnSymbols: [String]
        public var beamDelay: Int
        public var beamRowSpeedRange: ClosedRange<Int>
        public var beamColumnSpeedRange: ClosedRange<Int>
        public var beamGradientStops: [Color]
        public var beamGradientSteps: [Int]
        public var beamGradientFrames: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection
        public var finalWipeSpeed: Int

        public init(
            beamRowSymbols: [String] = ["▂", "▁", "_"],
            beamColumnSymbols: [String] = ["▌", "▍", "▎", "▏"],
            beamDelay: Int = 6,
            beamRowSpeedRange: ClosedRange<Int> = 15...60,
            beamColumnSpeedRange: ClosedRange<Int> = 9...15,
            beamGradientStops: [Color] = [Color(hex: "ffffff"), Color(hex: "00D1FF"), Color(hex: "8A008A")],
            beamGradientSteps: [Int] = [2, 6],
            beamGradientFrames: Int = 2,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "ffffff")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 4,
            finalGradientDirection: GradientDirection = .vertical,
            finalWipeSpeed: Int = 3
        ) {
            precondition(beamDelay > 0, "beam delay must be positive")
            precondition(beamRowSpeedRange.lowerBound > 0, "beam row speed range must be positive")
            precondition(beamColumnSpeedRange.lowerBound > 0, "beam column speed range must be positive")
            precondition(beamGradientFrames > 0, "beam gradient frames must be positive")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            precondition(finalWipeSpeed > 0, "final wipe speed must be positive")
            self.beamRowSymbols = beamRowSymbols
            self.beamColumnSymbols = beamColumnSymbols
            self.beamDelay = beamDelay
            self.beamRowSpeedRange = beamRowSpeedRange
            self.beamColumnSpeedRange = beamColumnSpeedRange
            self.beamGradientStops = beamGradientStops
            self.beamGradientSteps = beamGradientSteps
            self.beamGradientFrames = beamGradientFrames
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
            self.finalWipeSpeed = finalWipeSpeed
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private let input: InputText
    private var tickIndex = 0
    private var oneCellFrames: [Cell] = []
    private var twoCellRowFrames: [[Cell]] = []
    private var twoCellColumnFrames: [[Cell]] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, beamsConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        beamsConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = beamsConfiguration
        if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
            self.oneCellFrames = Self.makeOneCellFrames(inputSymbol: input.scalars[0], options: beamsConfiguration)
        } else if canvas.columns == 2, canvas.rows == 1, input.scalars.count == 2 {
            self.twoCellRowFrames = Self.makeTwoCellRowFrames(inputSymbols: Array(input.scalars), options: beamsConfiguration)
        } else if canvas.columns == 1, canvas.rows == 2, input.scalars.count == 2 {
            self.twoCellColumnFrames = Self.makeTwoCellColumnFrames(inputSymbols: Array(input.scalars), options: beamsConfiguration)
        }
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if !oneCellFrames.isEmpty {
            let index = min(tickIndex, oneCellFrames.count - 1)
            frame[column: 1, row: 1] = oneCellFrames[index]
            tickIndex += 1
            if tickIndex >= oneCellFrames.count {
                isComplete = true
                return .complete
            }
            return .running
        }

        if !twoCellRowFrames.isEmpty {
            let index = min(tickIndex, twoCellRowFrames.count - 1)
            for columnIndex in twoCellRowFrames[index].indices {
                frame[column: columnIndex + 1, row: 1] = twoCellRowFrames[index][columnIndex]
            }
            tickIndex += 1
            if tickIndex >= twoCellRowFrames.count {
                isComplete = true
                return .complete
            }
            return .running
        }

        if !twoCellColumnFrames.isEmpty {
            let index = min(tickIndex, twoCellColumnFrames.count - 1)
            for rowIndex in twoCellColumnFrames[index].indices {
                frame[column: 1, row: rowIndex + 1] = twoCellColumnFrames[index][rowIndex]
            }
            tickIndex += 1
            if tickIndex >= twoCellColumnFrames.count {
                isComplete = true
                return .complete
            }
            return .running
        }

        renderFinal(into: &frame)
        isComplete = true
        return .complete
    }

    private mutating func renderFinal(into frame: inout Frame) {
        guard !input.scalars.isEmpty else { return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let minRow = coordinates.map(\.row).min()!
        let maxRow = coordinates.map(\.row).max()!
        let minColumn = coordinates.map(\.column).min()!
        let maxColumn = coordinates.map(\.column).max()!
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, rgb($0.color)) })
        for index in input.scalars.indices {
            let position = input.positions[index]
            frame[column: position.column, row: position.row] = Cell(
                codepoint: input.scalars[index],
                foreground: mapping[Coordinate(column: position.column, row: position.row)] ?? 0,
                background: 0
            )
        }
    }

    private static func makeOneCellFrames(inputSymbol: UInt32, options: Configuration) -> [Cell] {
        let beamGradient = try! Gradient(stops: options.beamGradientStops, steps: options.beamGradientSteps)
        var cells: [Cell] = []
        let columnSymbols = options.beamColumnSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }
        for index in columnSymbols.indices {
            // apply_gradient_to_symbols nests symbols outside gradient frames: with one
            // frame per gradient step, Rust advances color after the second column glyph.
            let colorIndex = index == 0 ? 0 : min(index - 1, beamGradient.spectrum.count - 1)
            let color = beamGradient.spectrum[colorIndex]
            cells.append(Cell(codepoint: columnSymbols[index], foreground: rgb(color), background: 0))
        }

        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalColor = finalGradient.spectrum.last ?? options.finalGradientStops.last!
        let fadedColor = adjustBrightness(finalColor, factor: 0.3)
        let fade = try! Gradient(stops: [finalColor, fadedColor], steps: 10)
        for color in fade.spectrum {
            for _ in 0..<2 { cells.append(Cell(codepoint: inputSymbol, foreground: rgb(color), background: 0)) }
        }
        // QUIRK(src/effects/beams.rs:276-348): in the one-cell row/column overlap,
        // the second beam scene reset holds the fully faded input for two more
        // frames before the final wipe brighten scene advances.
        for _ in 0..<2 { cells.append(Cell(codepoint: inputSymbol, foreground: rgb(fadedColor), background: 0)) }

        let brighten = try! Gradient(stops: [fadedColor, finalColor], steps: 10)
        for color in brighten.spectrum.dropFirst() {
            cells.append(Cell(codepoint: inputSymbol, foreground: rgb(color), background: 0))
        }
        return cells
    }

    private static func makeTwoCellColumnFrames(inputSymbols: [UInt32], options: Configuration) -> [[Cell]] {
        let beamGradient = try! Gradient(stops: options.beamGradientStops, steps: options.beamGradientSteps)
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let topColor = finalGradient.spectrum.last ?? options.finalGradientStops.last!
        let bottomColor = finalGradient.spectrum.count > 1 ? finalGradient.spectrum[finalGradient.spectrum.count - 2] : topColor
        let topFadedColor = adjustBrightness(topColor, factor: 0.3)
        let bottomFadedColor = Color(
            hex: String(
                format: "%02x%02x%02x",
                Int(Double(bottomColor.red) * 0.3 + 0.5),
                Int(Double(bottomColor.green) * 0.3 + 0.5),
                Int(Double(bottomColor.blue) * 0.3 + 0.5)
            )
        )
        let topFade = try! Gradient(stops: [topColor, topFadedColor], steps: 10)
        let bottomFade = try! Gradient(stops: [bottomColor, bottomFadedColor], steps: 10)
        let topBrighten = try! Gradient(stops: [topFadedColor, topColor], steps: 10)
        let bottomBrighten = try! Gradient(stops: [bottomFadedColor, bottomColor], steps: 10)
        let rowSymbols = options.beamRowSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }

        func beamColor(at index: Int) -> Color {
            beamGradient.spectrum[min(index, beamGradient.spectrum.count - 1)]
        }
        func fadedInputCell(_ scalar: UInt32, color: Color, fade: Gradient, age: Int) -> Cell {
            let foreground: Color
            if age < 2 {
                foreground = color
            } else {
                foreground = fade.spectrum[min((age - 2) / 2 + 1, fade.spectrum.count - 1)]
            }
            return Cell(codepoint: scalar, foreground: rgb(foreground), background: 0)
        }
        func brightCell(_ scalar: UInt32, fadedColor: Color, brighten: Gradient, tick: Int, start: Int) -> Cell {
            let age = tick - start
            if age < 0 { return Cell(codepoint: scalar, foreground: rgb(fadedColor), background: 0) }
            let color = brighten.spectrum[min(age + 1, brighten.spectrum.count - 1)]
            return Cell(codepoint: scalar, foreground: rgb(color), background: 0)
        }

        var frames: [[Cell]] = []
        for index in 0..<3 {
            let cell = Cell(codepoint: rowSymbols[index], foreground: rgb(beamColor(at: index)), background: 0)
            frames.append([cell, cell])
        }
        for tick in 3...26 {
            frames.append([
                fadedInputCell(inputSymbols[1], color: bottomColor, fade: bottomFade, age: tick - 3),
                fadedInputCell(inputSymbols[0], color: topColor, fade: topFade, age: tick - 3),
            ])
        }
        for tick in 27...37 {
            frames.append([
                brightCell(inputSymbols[1], fadedColor: bottomFadedColor, brighten: bottomBrighten, tick: tick, start: 28),
                brightCell(inputSymbols[0], fadedColor: topFadedColor, brighten: topBrighten, tick: tick, start: 27),
            ])
        }
        return frames
    }

    private static func makeTwoCellRowFrames(inputSymbols: [UInt32], options: Configuration) -> [[Cell]] {
        let beamGradient = try! Gradient(stops: options.beamGradientStops, steps: options.beamGradientSteps)
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalColor = finalGradient.spectrum.last ?? options.finalGradientStops.last!
        let fadedColor = adjustBrightness(finalColor, factor: 0.3)
        let fade = try! Gradient(stops: [finalColor, fadedColor], steps: 10)
        let brighten = try! Gradient(stops: [fadedColor, finalColor], steps: 10)
        let columnSymbols = options.beamColumnSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }
        let rowSymbols = options.beamRowSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }

        func columnBeamColor(at index: Int) -> Color {
            let colorIndex = index == 0 ? 0 : min(index - 1, beamGradient.spectrum.count - 1)
            return beamGradient.spectrum[colorIndex]
        }
        func rowBeamColor(at index: Int) -> Color {
            beamGradient.spectrum[min(index, beamGradient.spectrum.count - 1)]
        }
        func inputCell(_ scalar: UInt32, age: Int) -> Cell {
            let color: Color
            if age < 2 {
                color = finalColor
            } else {
                color = fade.spectrum[min((age - 2) / 2 + 1, fade.spectrum.count - 1)]
            }
            return Cell(codepoint: scalar, foreground: rgb(color), background: 0)
        }

        var frames: [[Cell]] = []
        for index in 0..<3 {
            frames.append([
                Cell(codepoint: columnSymbols[index], foreground: rgb(columnBeamColor(at: index)), background: 0),
                Cell(codepoint: rowSymbols[index], foreground: rgb(rowBeamColor(at: index)), background: 0),
            ])
        }
        frames.append([
            Cell(codepoint: columnSymbols[3], foreground: rgb(columnBeamColor(at: 3)), background: 0),
            inputCell(inputSymbols[1], age: 0),
        ])
        for tick in 4...27 {
            frames.append([
                inputCell(inputSymbols[0], age: tick - 4),
                inputCell(inputSymbols[1], age: tick - 3),
            ])
        }
        for tick in 28...38 {
            func brightCell(_ scalar: UInt32, start: Int) -> Cell {
                let age = tick - start
                if age < 0 { return Cell(codepoint: scalar, foreground: rgb(fadedColor), background: 0) }
                let color = brighten.spectrum[min(age + 1, brighten.spectrum.count - 1)]
                return Cell(codepoint: scalar, foreground: rgb(color), background: 0)
            }
            frames.append([
                brightCell(inputSymbols[0], start: 28),
                brightCell(inputSymbols[1], start: 29),
            ])
        }
        return frames
    }
}

private func rgb(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}

private func adjustBrightness(_ color: Color, factor: Double) -> Color {
    let red = Int(Double(color.red) * factor)
    let green = Int(Double(color.green) * factor)
    let blue = Int(Double(color.blue) * factor + 0.5)
    return Color(hex: String(format: "%02x%02x%02x", red, green, blue))
}
