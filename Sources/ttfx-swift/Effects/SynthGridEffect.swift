import TTFXCore

public struct SynthGridEffect: Effect {
    public struct Configuration: Sendable {
        public var gridGradientStops: [Color]
        public var gridGradientSteps: [Int]
        public var gridGradientDirection: GradientDirection
        public var textGradientStops: [Color]
        public var textGradientSteps: [Int]
        public var textGradientDirection: GradientDirection
        public var gridRowSymbol: String
        public var gridColumnSymbol: String
        public var textGenerationSymbols: [String]
        public var maxActiveBlocks: Double

        public init(
            gridGradientStops: [Color] = [Color(hex: "CC00CC"), Color(hex: "FFFFFF")],
            gridGradientSteps: [Int] = [12],
            gridGradientDirection: GradientDirection = .diagonal,
            textGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            textGradientSteps: [Int] = [12],
            textGradientDirection: GradientDirection = .vertical,
            gridRowSymbol: String = "─",
            gridColumnSymbol: String = "│",
            textGenerationSymbols: [String] = ["░", "▒", "▓"],
            maxActiveBlocks: Double = 0.1
        ) {
            self.gridGradientStops = gridGradientStops
            self.gridGradientSteps = gridGradientSteps
            self.gridGradientDirection = gridGradientDirection
            self.textGradientStops = textGradientStops
            self.textGradientSteps = textGradientSteps
            self.textGradientDirection = textGradientDirection
            self.gridRowSymbol = gridRowSymbol
            self.gridColumnSymbol = gridColumnSymbol
            self.textGenerationSymbols = textGenerationSymbols
            self.maxActiveBlocks = maxActiveBlocks
        }
    }

    private enum Phase { case gridExpand, addChars, collapse, complete }
    private enum Direction { case horizontal, vertical }

    private struct GridLine {
        var direction: Direction
        var coordinates: [Coordinate]
        var collapsed: [Coordinate]
        var extended: [Coordinate] = []

        var isExtended: Bool { collapsed.isEmpty }
        var isCollapsed: Bool { extended.isEmpty }

        mutating func extend() {
            let count = direction == .horizontal ? 3 : 1
            for _ in 0..<count where !collapsed.isEmpty {
                extended.append(collapsed.removeFirst())
            }
        }

        mutating func collapse() {
            let count = direction == .horizontal ? 3 : 1
            if collapsed.isEmpty { extended.reverse() }
            for _ in 0..<count where !extended.isEmpty {
                collapsed.append(extended.removeFirst())
            }
        }
    }

    private struct CharacterScene {
        let coordinate: Coordinate
        var generationCells: [(codepoint: UInt32, color: UInt32)]
        let finalCodepoint: UInt32
        let finalColor: UInt32
        var age: Int = 0
        var active: Bool = false
        var complete: Bool = false

        var currentCell: (codepoint: UInt32, color: UInt32)? {
            guard age > 0, age <= generationCells.count * 2 else { return nil }
            return generationCells[(age - 1) / 2]
        }
    }

    private let canvas: Canvas
    private let input: InputText
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var tickIndex = 0
    private var isComplete = false
    private var built = false
    private var phase: Phase = .gridExpand
    private var gridLines: [GridLine] = []
    private var pendingGroups: [[Int]] = []
    private var allGroups: [[Int]] = []
    private var characterScenes: [CharacterScene] = []

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: seed,
            synthGridConfiguration: .init()
        )
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        synthGridConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = synthGridConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        if !built { build() }
        advancePhase()
        advanceActiveScenes()
        renderSynthGrid(into: &frame)
        tickIndex += 1

        if phase == .complete {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build() {
        built = true
        gridLines = [
            GridLine(direction: .horizontal, coordinates: (1...canvas.columns).map { Coordinate(column: $0, row: 1) }, collapsed: (1...canvas.columns).map { Coordinate(column: $0, row: 1) }),
            GridLine(direction: .horizontal, coordinates: (1...canvas.columns).map { Coordinate(column: $0, row: canvas.rows) }, collapsed: (1...canvas.columns).map { Coordinate(column: $0, row: canvas.rows) }),
            GridLine(direction: .vertical, coordinates: (1..<canvas.rows).map { Coordinate(column: 1, row: $0) }, collapsed: (1..<canvas.rows).map { Coordinate(column: 1, row: $0) }),
            GridLine(direction: .vertical, coordinates: (1..<canvas.rows).map { Coordinate(column: canvas.columns, row: $0) }, collapsed: (1..<canvas.rows).map { Coordinate(column: canvas.columns, row: $0) })
        ]
        let partitionIndexes = partitionLineIndexes()
        for row in partitionIndexes.rows {
            let coordinates = (1...canvas.columns).map { Coordinate(column: $0, row: row) }
            gridLines.append(GridLine(direction: .horizontal, coordinates: coordinates, collapsed: coordinates))
        }
        for column in partitionIndexes.columns {
            let coordinates = (1..<canvas.rows).map { Coordinate(column: column, row: $0) }
            gridLines.append(GridLine(direction: .vertical, coordinates: coordinates, collapsed: coordinates))
        }

        let finalColors = textColorMapping()
        var inputByCoordinate: [Coordinate: (codepoint: UInt32, color: UInt32)] = [:]
        for index in input.scalars.indices {
            let position = input.positions[index]
            inputByCoordinate[Coordinate(column: position.column, row: position.row)] = (input.scalars[index], finalColors[index])
        }
        let textGradient = try! Gradient(stops: options.textGradientStops, steps: options.textGradientSteps)
        characterScenes = []
        for row in 1...canvas.rows {
            for column in 1...canvas.columns {
                let coordinate = Coordinate(column: column, row: row)
                let final = inputByCoordinate[coordinate]
                characterScenes.append(CharacterScene(
                    coordinate: coordinate,
                    generationCells: [],
                    finalCodepoint: final?.codepoint ?? Cell.blank.codepoint,
                    finalColor: final?.color ?? 0
                ))
            }
        }
        pendingGroups = makeGroups()
        allGroups = pendingGroups
        for group in pendingGroups {
            for index in group {
                let count = rng.integer(in: 15...30)
                for _ in 0..<count {
                    let symbol = options.textGenerationSymbols[rng.integer(in: options.textGenerationSymbols.indices)]
                    let color = synthGridRGB(textGradient.spectrum[rng.integer(in: textGradient.spectrum.indices)])
                    characterScenes[index].generationCells.append((symbol.unicodeScalars.first!.value, color))
                }
            }
        }
        rng.shuffle(&pendingGroups)
        if pendingGroups.isEmpty {
            for index in characterScenes.indices { characterScenes[index].active = true }
        }
    }

    private mutating func advancePhase() {
        switch phase {
        case .gridExpand:
            if gridLines.allSatisfy(\.isExtended) {
                phase = .addChars
            } else {
                for index in gridLines.indices where !gridLines[index].isExtended { gridLines[index].extend() }
            }
        case .addChars:
            let activeGroupCount = allGroups.filter { group in group.contains { characterScenes[$0].active && !characterScenes[$0].complete } }.count
            let totalGroupCount = allGroups.count
            if !pendingGroups.isEmpty && Double(activeGroupCount) < Double(totalGroupCount) * options.maxActiveBlocks {
                let group = pendingGroups.removeFirst()
                for index in group { characterScenes[index].active = true }
            }
            if pendingGroups.isEmpty && !characterScenes.contains(where: { $0.active && !$0.complete }) {
                phase = .collapse
            }
        case .collapse:
            if gridLines.allSatisfy(\.isCollapsed) {
                phase = .complete
            } else {
                for index in gridLines.indices where !gridLines[index].isCollapsed { gridLines[index].collapse() }
            }
        case .complete:
            break
        }
    }

    private mutating func advanceActiveScenes() {
        for index in characterScenes.indices where characterScenes[index].active && !characterScenes[index].complete {
            characterScenes[index].age += 1
            if characterScenes[index].age >= characterScenes[index].generationCells.count * 2 + 1 {
                characterScenes[index].complete = true
            }
        }
    }

    private func renderSynthGrid(into frame: inout Frame) {
        for scene in characterScenes where scene.active {
            if !scene.complete, let currentCell = scene.currentCell {
                frame[column: scene.coordinate.column, row: scene.coordinate.row] = Cell(
                    codepoint: currentCell.codepoint,
                    foreground: currentCell.color,
                    background: 0
                )
            } else {
                frame[column: scene.coordinate.column, row: scene.coordinate.row] = Cell(
                    codepoint: scene.finalCodepoint,
                    foreground: scene.finalColor,
                    background: 0
                )
            }
        }

        for line in gridLines {
            let symbol = line.direction == .horizontal ? options.gridRowSymbol : options.gridColumnSymbol
            let codepoint = symbol.unicodeScalars.first?.value ?? Cell.blank.codepoint
            for coordinate in line.extended {
                frame[column: coordinate.column, row: coordinate.row] = Cell(codepoint: codepoint, foreground: gridColor(at: coordinate), background: 0)
            }
        }
    }

    private func makeGroups() -> [[Int]] {
        guard !characterScenes.isEmpty else { return [] }

        var rowIndexes = partitionLineIndexes().rows
        var columnIndexes = partitionLineIndexes().columns
        rowIndexes.append(canvas.rows + 1)
        columnIndexes.append(canvas.columns + 1)

        var groups: [[Int]] = []
        var previousRowIndex = 1
        for rowIndexValue in rowIndexes {
            var blockEndRow = rowIndexValue
            var previousColumnIndex = 1
            for blockEndColumn in columnIndexes {
                if blockEndRow == canvas.rows { blockEndRow += 1 }
                var group: [Int] = []
                for row in previousRowIndex..<blockEndRow {
                    for column in previousColumnIndex..<blockEndColumn {
                        if let index = characterScenes.firstIndex(where: { $0.coordinate == Coordinate(column: column, row: row) }) {
                            group.append(index)
                        }
                    }
                }
                if !group.isEmpty { groups.append(group) }
                previousColumnIndex = blockEndColumn
            }
            previousRowIndex = blockEndRow
        }
        return groups
    }

    private func partitionLineIndexes() -> (rows: [Int], columns: [Int]) {
        var rowIndexes: [Int] = []
        var columnIndexes: [Int] = []
        let rowGap: Int
        let columnGap: Int
        if canvas.rows > 2 * canvas.columns {
            rowGap = Self.findEvenGap(canvas.rows) + 1
            columnGap = rowGap * 2
        } else {
            columnGap = Self.findEvenGap(canvas.columns) + 1
            rowGap = columnGap / 2
        }

        var rowIndex = 1 + rowGap
        while rowIndex < canvas.rows {
            if canvas.rows - rowIndex >= 2 { rowIndexes.append(rowIndex) }
            rowIndex += max(rowGap, 1)
        }
        var columnIndex = 1 + columnGap
        while columnIndex < canvas.columns {
            if canvas.columns - columnIndex >= 2 { columnIndexes.append(columnIndex) }
            columnIndex += max(columnGap, 1)
        }
        return (rowIndexes, columnIndexes)
    }

    private static func findEvenGap(_ dimension: Int) -> Int {
        let adjusted = dimension - 2
        guard adjusted > 0 else { return 0 }
        var potentialGaps: [Int] = []
        var gap = adjusted
        while gap > 4 {
            if adjusted % gap <= 1 { potentialGaps.append(gap) }
            gap -= 1
        }
        guard let first = potentialGaps.first else { return 4 }
        let target = adjusted / 5
        return potentialGaps.dropFirst().reduce(first) { best, candidate in
            abs(candidate - target) < abs(best - target) ? candidate : best
        }
    }

    private func textColorMapping() -> [UInt32] {
        guard !input.scalars.isEmpty else { return [] }
        let minRow = input.positions.map(\.row).min()!
        let maxRow = input.positions.map(\.row).max()!
        let minColumn = input.positions.map(\.column).min()!
        let maxColumn = input.positions.map(\.column).max()!
        let gradient = try! Gradient(stops: options.textGradientStops, steps: options.textGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.textGradientDirection
        )).entries.map { ($0.coordinate, synthGridRGB($0.color)) })
        return input.positions.map { mapping[Coordinate(column: $0.column, row: $0.row)] ?? 0 }
    }

    private func gridColor(at coordinate: Coordinate) -> UInt32 {
        let gradient = try! Gradient(stops: options.gridGradientStops, steps: options.gridGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: 1,
            maxRow: canvas.rows,
            minColumn: 1,
            maxColumn: canvas.columns,
            direction: options.gridGradientDirection
        )).entries.map { ($0.coordinate, synthGridRGB($0.color)) })
        return mapping[coordinate] ?? 0xFFFFFF
    }


}

private func synthGridRGB(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}
