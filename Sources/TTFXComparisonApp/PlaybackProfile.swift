import SwiftUI

/// Forward-only SwiftUI timing curves applied to source-media time.
enum PlaybackProfile: String, CaseIterable, Sendable {
    case none = "None"
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In Out"

    var isConstant: Bool { self == .none || self == .linear }

    private var curve: UnitCurve {
        switch self {
        case .none, .linear: .linear
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        }
    }

    func position(start: Double, elapsed: Double, speed: Double, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        let start = min(duration, max(0, start))
        guard elapsed > 0 else { return start }
        if isConstant { return min(duration, start + elapsed * speed) }
        // Inversion preserves position when resuming, seeking, or changing profiles.
        let phase = curve.inverse.value(at: start / duration)
        let progress = min(1, phase + elapsed * speed / duration)
        return progress >= 1 ? duration : duration * curve.value(at: progress)
    }

    /// Average rate over the next display-clock interval: finite even at endpoints.
    func rate(start: Double, elapsed: Double, speed: Double, duration: Double, interval: Double) -> Double {
        if isConstant { return speed }
        let current = position(start: start, elapsed: elapsed, speed: speed, duration: duration)
        let next = position(start: start, elapsed: elapsed + interval, speed: speed, duration: duration)
        return max(0, (next - current) / interval)
    }
}
