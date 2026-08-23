import TTFXCore

public struct LaserEtchEffect: Effect {
    public struct Configuration: Sendable {
        public enum EtchPattern: Sendable {
            case algorithm
            case rowTopToBottom
        }

        public var etchPattern: EtchPattern

        public init(etchPattern: EtchPattern = .algorithm) {
            self.etchPattern = etchPattern
        }
    }

    private let laserEtchConfiguration: Configuration
    private var emittedGroupedDeadBranchFrame = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: seed,
            laserEtchConfiguration: .init()
        )
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        laserEtchConfiguration: Configuration
    ) {
        self.laserEtchConfiguration = laserEtchConfiguration
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        switch laserEtchConfiguration.etchPattern {
        case .rowTopToBottom:
            guard !emittedGroupedDeadBranchFrame else { return .complete }
            emittedGroupedDeadBranchFrame = true
            return .complete
        case .algorithm:
            return .complete
        }
    }
}
