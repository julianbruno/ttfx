public protocol RuntimeEffect: Effect {
    var runtime: AnimationRuntime { get set }
    mutating func buildRuntime()
    mutating func scheduleTick()
    mutating func receiveRuntimeEvent(_ event: EffectEvent)
}

public extension RuntimeEffect {
    init(configuration: EffectConfiguration, canvas: Canvas) {
        self.init(configuration: configuration, canvas: canvas, input: canvas.ingest(configuration.text), seed: configuration.seed)
    }

    mutating func tick(into frame: inout Frame) -> TickStatus {
        if !runtime.runtimeBuilt {
            buildRuntime()
            runtime.runtimeBuilt = true
        }
        scheduleTick()
        let status = runtime.tick(into: &frame)
        for event in runtime.drainEmittedEvents() {
            receiveRuntimeEvent(event)
        }
        return status
    }

    mutating func receiveRuntimeEvent(_ event: EffectEvent) {}
}
