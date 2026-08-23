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

public struct TTFXMetalCellSize: Equatable, Sendable {
    public let width: Float
    public let height: Float

    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}

public struct TTFXMetalDrawableSize: Equatable, Sendable {
    public let width: Float
    public let height: Float

    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}

public struct TTFXMetalGlyphCell: Equatable, Sendable {
    public let codepoint: UInt32
    public let foregroundRGB: UInt32
    public let backgroundRGB: UInt32
    public let column: UInt16
    public let row: UInt16
    public let cellOriginX: Float
    public let cellOriginY: Float

    public init(cell: TTFXRenderableCell, cellSize: TTFXMetalCellSize) {
        self.codepoint = cell.codepoint
        self.foregroundRGB = cell.foreground & 0x00ff_ffff
        self.backgroundRGB = cell.background & 0x00ff_ffff
        self.column = UInt16(clamping: cell.column - 1)
        self.row = UInt16(clamping: cell.row - 1)
        self.cellOriginX = Float(cell.column - 1) * cellSize.width
        self.cellOriginY = Float(cell.row - 1) * cellSize.height
    }
}

public struct TTFXMetalFrameUploadPlan: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let cellSize: TTFXMetalCellSize
    public let cells: [TTFXMetalGlyphCell]

    public init(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize) {
        self.columns = snapshot.columns
        self.rows = snapshot.rows
        self.cellSize = cellSize
        self.cells = snapshot.cells.map { TTFXMetalGlyphCell(cell: $0, cellSize: cellSize) }
    }

    public var cellCount: Int { cells.count }
    public var byteCount: Int { MemoryLayout<TTFXMetalGlyphCell>.stride * cells.count }
}

public enum TTFXMetalCommandOperation: Equatable, Sendable {
    case allocateGlyphCellBuffer(bytes: Int)
    case uploadGlyphCells(count: Int)
    case encodeGlyphDraw(count: Int)
    case skipGPUEncoding(reason: String)
}

public struct TTFXMetalCommandPlan: Equatable, Sendable {
    public static let headlessSkipReason = "Metal device or drawable unavailable in headless test environment"

    public let uploadPlan: TTFXMetalFrameUploadPlan
    public let drawableSize: TTFXMetalDrawableSize
    public let operations: [TTFXMetalCommandOperation]

    public init(uploadPlan: TTFXMetalFrameUploadPlan, drawableSize: TTFXMetalDrawableSize, canEncodeGPUCommands: Bool) {
        self.uploadPlan = uploadPlan
        self.drawableSize = drawableSize
        if canEncodeGPUCommands {
            self.operations = [
                .allocateGlyphCellBuffer(bytes: uploadPlan.byteCount),
                .uploadGlyphCells(count: uploadPlan.cellCount),
                .encodeGlyphDraw(count: uploadPlan.cellCount),
            ]
        } else {
            self.operations = [
                .allocateGlyphCellBuffer(bytes: uploadPlan.byteCount),
                .uploadGlyphCells(count: uploadPlan.cellCount),
                .skipGPUEncoding(reason: Self.headlessSkipReason),
            ]
        }
    }
}

#if canImport(Metal)
import Metal

public final class TTFXMetalRenderer {
    public static var hasDefaultDevice: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    public let deviceName: String?
    public private(set) var lastUploadPlan: TTFXMetalFrameUploadPlan?
    public private(set) var lastGlyphCellBufferLength: Int = 0

    private let device: (any MTLDevice)?
    private let commandQueue: (any MTLCommandQueue)?
    private var glyphCellBuffer: (any MTLBuffer)?

    public var canEncodeGPUCommands: Bool {
        device != nil && commandQueue != nil
    }

    public init(device: (any MTLDevice)? = MTLCreateSystemDefaultDevice()) {
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.deviceName = device?.name
    }

    public func makeUploadPlan(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize) -> TTFXMetalFrameUploadPlan {
        TTFXMetalFrameUploadPlan(snapshot: snapshot, cellSize: cellSize)
    }

    public func makeCommandPlan(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize, drawableSize: TTFXMetalDrawableSize) -> TTFXMetalCommandPlan {
        TTFXMetalCommandPlan(
            uploadPlan: makeUploadPlan(snapshot: snapshot, cellSize: cellSize),
            drawableSize: drawableSize,
            canEncodeGPUCommands: canEncodeGPUCommands
        )
    }

    public func prepare(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize, drawableSize: TTFXMetalDrawableSize) -> TTFXMetalCommandPlan {
        let commandPlan = makeCommandPlan(snapshot: snapshot, cellSize: cellSize, drawableSize: drawableSize)
        lastUploadPlan = commandPlan.uploadPlan

        guard canEncodeGPUCommands else { return commandPlan }
        glyphCellBuffer = commandPlan.uploadPlan.cells.withUnsafeBufferPointer { cells in
            guard let baseAddress = cells.baseAddress, commandPlan.uploadPlan.byteCount > 0 else {
                return device?.makeBuffer(length: 0, options: [.storageModeShared])
            }
            return device?.makeBuffer(bytes: baseAddress, length: commandPlan.uploadPlan.byteCount, options: [.storageModeShared])
        }
        lastGlyphCellBufferLength = glyphCellBuffer?.length ?? 0
        _ = commandQueue?.makeCommandBuffer()
        return commandPlan
    }
}
#else
public final class TTFXMetalRenderer {
    public static var hasDefaultDevice: Bool { false }
    public let deviceName: String? = nil
    public private(set) var lastUploadPlan: TTFXMetalFrameUploadPlan?
    public private(set) var lastGlyphCellBufferLength: Int = 0
    public var canEncodeGPUCommands: Bool { false }

    public init() {}

    public func makeUploadPlan(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize) -> TTFXMetalFrameUploadPlan {
        TTFXMetalFrameUploadPlan(snapshot: snapshot, cellSize: cellSize)
    }

    public func makeCommandPlan(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize, drawableSize: TTFXMetalDrawableSize) -> TTFXMetalCommandPlan {
        TTFXMetalCommandPlan(
            uploadPlan: makeUploadPlan(snapshot: snapshot, cellSize: cellSize),
            drawableSize: drawableSize,
            canEncodeGPUCommands: false
        )
    }

    public func prepare(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize, drawableSize: TTFXMetalDrawableSize) -> TTFXMetalCommandPlan {
        let commandPlan = makeCommandPlan(snapshot: snapshot, cellSize: cellSize, drawableSize: drawableSize)
        lastUploadPlan = commandPlan.uploadPlan
        return commandPlan
    }
}
#endif
