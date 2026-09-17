public struct EffectEngine<Animation: Effect> {
    public let configuration: EffectConfiguration
    public let canvas: Canvas
    public let input: InputText
    public private(set) var frame: Frame
    public private(set) var status: TickStatus
    private var effect: Animation

    public init(configuration: EffectConfiguration, canvas: Canvas) throws {
        let input = canvas.ingest(configuration.text)
        self.configuration = configuration
        self.canvas = canvas
        self.input = input
        self.frame = try Frame(columns: canvas.columns, rows: canvas.rows)
        self.status = .running
        self.effect = Animation(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: configuration.seed
        )
    }

    @discardableResult
    public mutating func tick() -> TickStatus {
        guard status == .running else { return .complete }
        frame.withMutableCells { cells in
            cells.withUnsafeMutableBufferPointer { $0.update(repeating: .blank) }
        }
        status = effect.tick(into: &frame)
        return status
    }

    public mutating func run(ticks: Int) -> TickRunResult {
        precondition(ticks >= 0, "tick count must not be negative")
        var executedTicks = 0
        while executedTicks < ticks && status == .running {
            _ = tick()
            executedTicks += 1
        }
        return TickRunResult(executedTicks: executedTicks, status: status)
    }
}
