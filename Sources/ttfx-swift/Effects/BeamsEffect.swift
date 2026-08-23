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

    private let canvas: Canvas
    private let options: Configuration
    private let input: InputText
    private var tickIndex = 0
    private var oneCellFrames: [Cell] = []
    private var twoCellRowFrames: [[Cell]] = []
    private var twoCellColumnFrames: [[Cell]] = []
    private var positionedFrames: [[(Coordinate, Cell)]] = []
    private var genericFrames: [[(Coordinate, Cell)]] = []
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
        } else if canvas.columns == 2, canvas.rows == 2, input.scalars.count == 4 {
            self.positionedFrames = Self.makeTwoByTwoFrames(
                inputSymbols: Array(input.scalars),
                inputPositions: input.positions,
                options: beamsConfiguration
            )
        } else {
            self.genericFrames = Self.makeGenericFrames(canvas: canvas, input: input, seed: seed, options: beamsConfiguration)
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

        if !positionedFrames.isEmpty {
            let index = min(tickIndex, positionedFrames.count - 1)
            for (coordinate, cell) in positionedFrames[index] {
                frame[column: coordinate.column, row: coordinate.row] = cell
            }
            tickIndex += 1
            if tickIndex >= positionedFrames.count {
                isComplete = true
                return .complete
            }
            return .running
        }

        if !genericFrames.isEmpty {
            let index = min(tickIndex, genericFrames.count - 1)
            for (coordinate, cell) in genericFrames[index] {
                frame[column: coordinate.column, row: coordinate.row] = cell
            }
            tickIndex += 1
            if tickIndex >= genericFrames.count {
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
        func beamCells(symbols: [UInt32], columnQuirk: Bool) -> [Cell] {
            symbols.enumerated().map { index, symbol in
                let colorIndex = columnQuirk && index > 0 ? index - 1 : index
                return coloredCell(symbol: symbol, color: beamGradient.spectrum[min(colorIndex, beamGradient.spectrum.count - 1)])
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
            return brighten.spectrum.map { coloredCell(symbol: symbol, color: $0) }
        }
        func sceneCells(for character: GenericCharacter, scene: GenericScene) -> [Cell] {
            switch scene {
            case .beamRow:
                return beamCells(symbols: rowSymbols, columnQuirk: false) + fadeCells(symbol: character.inputSymbol, color: character.finalColor)
            case .beamColumn:
                return beamCells(symbols: columnSymbols, columnQuirk: true) + fadeCells(symbol: character.inputSymbol, color: character.finalColor)
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

        while frames.count < 300 {
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

        let finalInputColors = Dictionary(uniqueKeysWithValues: inputCoordinates.map { coordinate in
            (coordinate, rgb(finalMapping[coordinate] ?? options.finalGradientStops.last!))
        })
        if let completeIndex = frames.indices.first(where: { index in
            index > 8 && finalInputColors.allSatisfy { coordinate, color in
                frames[index].first(where: { $0.0 == coordinate })?.1.foreground == color
            }
        }) {
            frames.removeSubrange((completeIndex + 1)..<frames.endIndex)
        }
        return frames
    }

    private static func makeTwoByTwoFrames(
        inputSymbols: [UInt32],
        inputPositions: ContiguousArray<InputPosition>,
        options: Configuration
    ) -> [[(Coordinate, Cell)]] {
        let coordinates = inputPositions.map { Coordinate(column: $0.column, row: $0.row) }
        let minRow = coordinates.map(\.row).min()!
        let maxRow = coordinates.map(\.row).max()!
        let minColumn = coordinates.map(\.column).min()!
        let maxColumn = coordinates.map(\.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMapping = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, $0.color) })
        let beamGradient = try! Gradient(stops: options.beamGradientStops, steps: options.beamGradientSteps)
        let rowSymbols = options.beamRowSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }

        func finalColor(for coordinate: Coordinate) -> Color {
            finalMapping[coordinate] ?? options.finalGradientStops.last!
        }
        func fadeGradient(for color: Color) -> Gradient {
            try! Gradient(stops: [color, rustAdjustedBrightness(color, factor: 0.3)], steps: 10)
        }
        func brightenGradient(for color: Color) -> Gradient {
            let faded = rustAdjustedBrightness(color, factor: 0.3)
            return try! Gradient(stops: [faded, color], steps: 10)
        }
        func fadingCell(scalar: UInt32, color: Color, age: Int) -> Cell {
            let fade = fadeGradient(for: color)
            let foreground: Color
            if age < 2 {
                foreground = color
            } else {
                foreground = fade.spectrum[min((age - 2) / 2 + 1, fade.spectrum.count - 1)]
            }
            return Cell(codepoint: scalar, foreground: rgb(foreground), background: 0)
        }
        func brightCell(scalar: UInt32, color: Color, tick: Int, start: Int) -> Cell {
            let faded = rustAdjustedBrightness(color, factor: 0.3)
            if tick < start { return Cell(codepoint: scalar, foreground: rgb(faded), background: 0) }
            let brighten = brightenGradient(for: color)
            let foreground = brighten.spectrum[min(tick - start + 1, brighten.spectrum.count - 1)]
            return Cell(codepoint: scalar, foreground: rgb(foreground), background: 0)
        }
        func frame(cells: [Cell]) -> [(Coordinate, Cell)] {
            zip(coordinates, cells).map { ($0.0, $0.1) }
        }
        func diagonalStart(for coordinate: Coordinate) -> Int {
            // Rust's DiagonalTopLeftToBottomRight final wipe releases one diagonal per tick.
            27 + (coordinate.column - minColumn) + (maxRow - coordinate.row)
        }

        var frames: [[(Coordinate, Cell)]] = []
        for index in 0..<3 {
            let symbol = rowSymbols[index]
            let color = beamGradient.spectrum[min(index, beamGradient.spectrum.count - 1)]
            frames.append(frame(cells: inputSymbols.map { _ in Cell(codepoint: symbol, foreground: rgb(color), background: 0) }))
        }
        for tick in 3...26 {
            frames.append(frame(cells: inputSymbols.enumerated().map { index, scalar in
                fadingCell(scalar: scalar, color: finalColor(for: coordinates[index]), age: tick - 3)
            }))
        }
        for tick in 27...38 {
            frames.append(frame(cells: inputSymbols.enumerated().map { index, scalar in
                let coordinate = coordinates[index]
                return brightCell(scalar: scalar, color: finalColor(for: coordinate), tick: tick, start: diagonalStart(for: coordinate))
            }))
        }
        return frames
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

private func rustAdjustedBrightness(_ color: Color, factor: Double) -> Color {
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
