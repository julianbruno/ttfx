import Foundation

/// Opt-in shared stream used by a synchronous CLI run and its resize rebuilds.
/// Ordinary effects keep independent RNG value semantics.
public final class RNGContinuation: @unchecked Sendable, Equatable {
    private let lock = NSLock()
    private var state: Xoshiro256PlusPlus
    public init(_ state: Xoshiro256PlusPlus) { self.state = state.snapshot() }
    public static func == (lhs: RNGContinuation, rhs: RNGContinuation) -> Bool { lhs === rhs }
    public func snapshot() -> Xoshiro256PlusPlus { lock.lock(); defer { lock.unlock() }; return state }
    func nextUInt64() -> UInt64 { lock.lock(); defer { lock.unlock() }; return state.nextUInt64() }
}

public final class EffectClock: Sendable, Equatable {
    public let now: @Sendable () -> Double
    public init(now: @escaping @Sendable () -> Double) { self.now = now }
    public static func == (lhs: EffectClock, rhs: EffectClock) -> Bool { lhs === rhs }
    public static var continuous: EffectClock { EffectClock(now: { ProcessInfo.processInfo.systemUptime }) }
}
