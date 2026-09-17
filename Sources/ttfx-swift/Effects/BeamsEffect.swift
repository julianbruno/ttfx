import Foundation
import TTFXCore

private let explicitBlackForegroundSentinel: UInt32 = 0xFFFF_FFFE

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

    private var frames: [[(Coordinate, Cell)]]
    private var tickIndex = 0

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, beamsConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, beamsConfiguration: Configuration) {
        frames = Self.makeGenericFrames(canvas: canvas, input: input, seed: seed, options: beamsConfiguration)
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard tickIndex < frames.count else { return .complete }
        for (coordinate, cell) in frames[tickIndex] { frame[column: coordinate.column, row: coordinate.row] = cell }
        tickIndex += 1
        return tickIndex == frames.count ? .complete : .running
    }

    private enum GenericScene {
        case beamRow
        case beamColumn
        case brighten
    }

    private struct GenericCharacter {
        let id: Int
        let coordinate: Coordinate
        let inputSymbol: UInt32
        let finalColor: Color
        var visible = false
        var scene: GenericScene?
        var sceneIndex = 0
        var currentCell = Cell.blank
    }

    private struct GenericGroup {
        var characters: [Int]
        let direction: GenericScene
        let speed: Double
        var nextCharacterCounter = 0.0
    }

    private static func makeGenericFrames(canvas: Canvas, input: InputText, seed: UInt64, options: Configuration) -> [[(Coordinate, Cell)]] {
        guard !input.scalars.isEmpty else { return [] }
        let beamGradient = try! Gradient(stops: options.beamGradientStops, steps: options.beamGradientSteps)
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let inputCoordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let inputByCoordinate = Dictionary(uniqueKeysWithValues: zip(inputCoordinates, input.scalars))
        let finalMapping = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: inputCoordinates.map(\.row).min()!,
            maxRow: inputCoordinates.map(\.row).max()!,
            minColumn: inputCoordinates.map(\.column).min()!,
            maxColumn: inputCoordinates.map(\.column).max()!,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, $0.color) })
        let rowSymbols = options.beamRowSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }
        let columnSymbols = options.beamColumnSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }

        func coloredCell(symbol: UInt32, color: Color) -> Cell {
            let word = rgb(color)
            return Cell(codepoint: symbol, foreground: word, background: word == 0 ? explicitBlackForegroundSentinel : 0)
        }
        func beamCells(symbols: [UInt32]) -> [Cell] {
            let colors = beamGradient.spectrum
            let count = max(symbols.count, colors.count)
            func distributedIndex(_ index: Int, count smaller: Int) -> Int {
                let base = count / smaller
                let remainder = count % smaller
                var boundary = 0
                for candidate in 0..<smaller {
                    boundary += base + (candidate < remainder ? 1 : 0)
                    if index < boundary { return candidate }
                }
                return smaller - 1
            }
            return (0..<count).flatMap { index in
                Array(repeating: coloredCell(symbol: symbols[distributedIndex(index, count: symbols.count)],
                    color: colors[distributedIndex(index, count: colors.count)]), count: options.beamGradientFrames)
            }
        }
        func fadeCells(symbol: UInt32, color: Color) -> [Cell] {
            let fade = try! Gradient(stops: [color, rustAdjustedBrightness(color, factor: 0.3)], steps: 10)
            return fade.spectrum.flatMap { color in
                (0..<2).map { _ in coloredCell(symbol: symbol, color: color) }
            }
        }
        func brightenCells(symbol: UInt32, color: Color) -> [Cell] {
            let faded = rustAdjustedBrightness(color, factor: 0.3)
            let brighten = try! Gradient(stops: [faded, color], steps: 10)
            return brighten.spectrum.flatMap { Array(repeating: coloredCell(symbol: symbol, color: $0), count: options.finalGradientFrames) }
        }
        func sceneCells(for character: GenericCharacter, scene: GenericScene) -> [Cell] {
            switch scene {
            case .beamRow:
                return beamCells(symbols: rowSymbols) + fadeCells(symbol: character.inputSymbol, color: character.finalColor)
            case .beamColumn:
                return beamCells(symbols: columnSymbols) + fadeCells(symbol: character.inputSymbol, color: character.finalColor)
            case .brighten:
                return brightenCells(symbol: character.inputSymbol, color: character.finalColor)
            }
        }

        var characters: [GenericCharacter] = []
        var idByCoordinate: [Coordinate: Int] = [:]
        for row in 1...canvas.rows {
            for column in 1...canvas.columns {
                let coordinate = Coordinate(column: column, row: row)
                let symbol = inputByCoordinate[coordinate] ?? Cell.blank.codepoint
                let color = inputByCoordinate[coordinate] == nil ? Color(hex: "000000") : (finalMapping[coordinate] ?? options.finalGradientStops.last!)
                let id = characters.count
                characters.append(GenericCharacter(id: id, coordinate: coordinate, inputSymbol: symbol, finalColor: color))
                idByCoordinate[coordinate] = id
            }
        }

        var rng = Xoshiro256PlusPlus(seed: seed)
        var groups: [GenericGroup] = []
        for row in stride(from: canvas.rows, through: 1, by: -1) {
            var ids = (1...canvas.columns).compactMap { idByCoordinate[Coordinate(column: $0, row: row)] }
            let speed = Double(rng.integer(in: options.beamRowSpeedRange)) * 0.1
            if rng.integer(in: 0...1) == 0 { ids.reverse() }
            groups.append(GenericGroup(characters: ids, direction: .beamRow, speed: speed))
        }
        for column in 1...canvas.columns {
            var ids = (1...canvas.rows).compactMap { idByCoordinate[Coordinate(column: column, row: $0)] }
            let speed = Double(rng.integer(in: options.beamColumnSpeedRange)) * 0.1
            if rng.integer(in: 0...1) == 0 { ids.reverse() }
            groups.append(GenericGroup(characters: ids, direction: .beamColumn, speed: speed))
        }
        rng.shuffle(&groups)

        var pendingGroups = groups
        var activeGroups: [GenericGroup] = []
        var activeCharacters = Set<Int>()
        var delay = 0
        enum Phase { case beams, finalWipe, complete }
        var phase = Phase.beams
        let minInputColumn = inputCoordinates.map(\.column).min()!
        let maxInputRow = inputCoordinates.map(\.row).max()!
        let inputCoordinateSet = Set(inputCoordinates)
        let groupedInputIDs = Dictionary(grouping: characters.filter { inputCoordinateSet.contains($0.coordinate) }) { character in
            (character.coordinate.column - minInputColumn) + (maxInputRow - character.coordinate.row)
        }
        var finalWipeGroups = groupedInputIDs.keys.sorted().map { key in
            groupedInputIDs[key, default: []].map(\.id)
        }
        var frames: [[(Coordinate, Cell)]] = []

        func activate(_ id: Int, _ scene: GenericScene) {
            characters[id].visible = true
            characters[id].scene = scene
            characters[id].sceneIndex = 0
            activeCharacters.insert(id)
        }
        func updateAndRender() -> [(Coordinate, Cell)] {
            var completed: [Int] = []
            for id in activeCharacters.sorted() {
                guard let scene = characters[id].scene else { completed.append(id); continue }
                let cells = sceneCells(for: characters[id], scene: scene)
                let index = min(characters[id].sceneIndex, cells.count - 1)
                characters[id].currentCell = cells[index]
                characters[id].sceneIndex += 1
                if characters[id].sceneIndex >= cells.count {
                    characters[id].scene = nil
                    completed.append(id)
                }
            }
            for id in completed { activeCharacters.remove(id) }
            return characters.filter(\.visible).map { ($0.coordinate, $0.currentCell) }
        }

        while true {
            if phase == .complete && activeCharacters.isEmpty { break }
            switch phase {
            case .beams:
                if delay == 0 {
                    if !pendingGroups.isEmpty {
                        for _ in 0..<rng.integer(in: 1...5) where !pendingGroups.isEmpty {
                            activeGroups.append(pendingGroups.removeFirst())
                        }
                    }
                    delay = options.beamDelay
                } else {
                    delay -= 1
                }
                for index in activeGroups.indices {
                    activeGroups[index].nextCharacterCounter += activeGroups[index].speed
                    let count = Int(activeGroups[index].nextCharacterCounter)
                    if count > 1 {
                        for _ in 0..<count where !activeGroups[index].characters.isEmpty {
                            let id = activeGroups[index].characters.removeFirst()
                            activeGroups[index].nextCharacterCounter -= 1.0
                            activate(id, activeGroups[index].direction)
                        }
                    }
                }
                activeGroups.removeAll { $0.characters.isEmpty }
                if pendingGroups.isEmpty && activeGroups.isEmpty && activeCharacters.isEmpty { phase = .finalWipe }
            case .finalWipe:
                if !finalWipeGroups.isEmpty {
                    for _ in 0..<options.finalWipeSpeed where !finalWipeGroups.isEmpty {
                        for id in finalWipeGroups.removeFirst() { activate(id, .brighten) }
                    }
                } else {
                    phase = .complete
                }
            case .complete:
                break
            }
            frames.append(updateAndRender())
        }

        return frames
    }

}

private func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }

func rustAdjustedBrightness(_ color: Color, factor: Double) -> Color {
    let normalizedRed = Double(color.red) / 255.0
    let normalizedGreen = Double(color.green) / 255.0
    let normalizedBlue = Double(color.blue) / 255.0
    let maxValue = max(normalizedRed, normalizedGreen, normalizedBlue)
    let minValue = min(normalizedRed, normalizedGreen, normalizedBlue)
    var lightness = (maxValue + minValue) / 2.0
    let threshold = 0.5
    let hue: Double
    let saturation: Double
    if maxValue == minValue {
        hue = 0
        saturation = 0
    } else {
        let difference = maxValue - minValue
        saturation = lightness > threshold ? difference / (2.0 - maxValue - minValue) : difference / (maxValue + minValue)
        var hueValue: Double
        if maxValue == normalizedRed {
            hueValue = (normalizedGreen - normalizedBlue) / difference + (normalizedGreen < normalizedBlue ? 6.0 : 0.0)
        } else if maxValue == normalizedGreen {
            hueValue = (normalizedBlue - normalizedRed) / difference + 2.0
        } else {
            hueValue = (normalizedRed - normalizedGreen) / difference + 4.0
        }
        hueValue /= 6.0
        hue = hueValue
    }

    lightness = min(max(lightness * factor, 0), 1)
    let red: Double
    let green: Double
    let blue: Double
    if saturation == 0 {
        red = lightness
        green = lightness
        blue = lightness
    } else {
        let colorIntensity = lightness < threshold
            ? lightness * (1.0 + saturation)
            : lightness + saturation - lightness * saturation
        let lightnessScaled = 2.0 * lightness - colorIntensity
        func hueToRGB(_ value: Double) -> Double {
            var hueValue = value
            if hueValue < 0 { hueValue += 1 }
            if hueValue > 1 { hueValue -= 1 }
            if hueValue < 1.0 / 6.0 { return lightnessScaled + (colorIntensity - lightnessScaled) * 6.0 * hueValue }
            if hueValue < 1.0 / 2.0 { return colorIntensity }
            if hueValue < 2.0 / 3.0 { return lightnessScaled + (colorIntensity - lightnessScaled) * (2.0 / 3.0 - hueValue) * 6.0 }
            return lightnessScaled
        }
        red = hueToRGB(hue + 1.0 / 3.0)
        green = hueToRGB(hue)
        blue = hueToRGB(hue - 1.0 / 3.0)
    }

    return Color(hex: String(
        format: "%02x%02x%02x",
        PyCompat.roundHalfEven(red * 255.0),
        PyCompat.roundHalfEven(green * 255.0),
        PyCompat.roundHalfEven(blue * 255.0)
    ))
}
