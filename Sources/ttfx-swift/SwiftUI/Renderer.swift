import TTFXCore

public protocol TTFXFrameRenderer {
    mutating func tick(at instant: Duration) throws -> TTFXFrameSnapshot
}

public struct TTFXDeterministicRenderer: TTFXFrameRenderer {
    public let frameInterval: Duration
    public private(set) var renderedFrameCount: Int = 0
    public private(set) var lastFrameStorageCapacity: Int = 0

    private var lastRenderInstant: Duration?
    private var lastSnapshot: TTFXFrameSnapshot?
    private var makeFrame: () throws -> Frame

    public init(frameInterval: Duration = .milliseconds(16), makeFrame: @escaping () throws -> Frame) {
        self.frameInterval = frameInterval
        self.makeFrame = makeFrame
    }

    public mutating func tick(at instant: Duration) throws -> TTFXFrameSnapshot {
        if let lastRenderInstant, let lastSnapshot, instant - lastRenderInstant < frameInterval {
            return lastSnapshot
        }

        let frame = try makeFrame()
        let snapshot = TTFXFrameSnapshot(frame: frame)
        renderedFrameCount += 1
        lastFrameStorageCapacity = frame.storageCapacity
        lastRenderInstant = instant
        lastSnapshot = snapshot
        return snapshot
    }
}

public struct TTFXMetalRendererAvailability: Equatable, Sendable {
    public let isAvailable: Bool
    public let message: String

    public static var current: TTFXMetalRendererAvailability {
        #if canImport(Metal)
        if TTFXMetalRenderer.hasDefaultDevice {
            TTFXMetalRendererAvailability(isAvailable: true, message: "Metal renderer available")
        } else {
            TTFXMetalRendererAvailability(isAvailable: false, message: "Metal renderer unavailable: no default device")
        }
        #else
        TTFXMetalRendererAvailability(isAvailable: false, message: "Metal renderer unavailable: Metal framework is not present")
        #endif
    }
}

#if canImport(Metal)
import Metal

public struct TTFXMetalRenderer {
    public static var hasDefaultDevice: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    public init() {}
}
#else
public struct TTFXMetalRenderer {
    public static var hasDefaultDevice: Bool { false }
    public init() {}
}
#endif
