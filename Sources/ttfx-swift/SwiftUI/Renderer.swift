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

    public init(isAvailable: Bool, message: String) {
        self.isAvailable = isAvailable
        self.message = message
    }

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
#if canImport(MetalKit)
import MetalKit
import Foundation
private enum TTFXMetalResourceError: Error { case missingShader }
#endif

public final class TTFXMetalRenderer {
    public static var hasDefaultDevice: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    public let deviceName: String?
    public private(set) var lastUploadPlan: TTFXMetalFrameUploadPlan?
    public private(set) var lastGlyphCellBufferLength: Int = 0

    public let device: (any MTLDevice)?
    private let commandQueue: (any MTLCommandQueue)?
    private var glyphCellBuffer: (any MTLBuffer)?
    public private(set) var lastPresentedDrawableSize: TTFXMetalDrawableSize?
    public private(set) var lastEncodedOperationCount = 0
    public private(set) var lastDrawError: String?
    private var pipeline: (any MTLRenderPipelineState)?
    #if canImport(MetalKit)
    private var atlas: TTFXMetalGlyphAtlas?
    #endif


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
                return nil
            }
            return device?.makeBuffer(bytes: baseAddress, length: commandPlan.uploadPlan.byteCount, options: [.storageModeShared])
        }
        lastGlyphCellBufferLength = glyphCellBuffer?.length ?? 0
        return commandPlan
    }
    #if canImport(MetalKit)
    @MainActor
    @discardableResult
    public func draw(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize, view: MTKView) -> TTFXMetalCommandPlan {
        let size = TTFXMetalDrawableSize(width: Float(view.drawableSize.width), height: Float(view.drawableSize.height))
        guard let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor else {
            resetDrawState()
            return TTFXMetalCommandPlan(uploadPlan: makeUploadPlan(snapshot: snapshot, cellSize: cellSize), drawableSize: size, canEncodeGPUCommands: false)
        }
        // Geometry is expressed in points; the viewport maps it to Retina pixels.
        let logicalSize = TTFXMetalDrawableSize(width: Float(view.bounds.width), height: Float(view.bounds.height))
        return draw(snapshot: snapshot, cellSize: cellSize, drawableSize: size, logicalSize: logicalSize, pass: pass) { commandBuffer in
            commandBuffer.present(drawable)
        }
    }

    /// The presentation closure is shared by MTKView and offscreen tests. Metrics
    /// report submission, never a claim that GPU pixels have appeared on screen.
    @discardableResult
    /// Exports pixels using the same atlas, shaders and encoding path as the live Metal view.
    public func exportBGRA(snapshot: TTFXFrameSnapshot, cellWidth: Int, cellHeight: Int) throws -> Data {
        guard let device, cellWidth > 0, cellHeight > 0 else {
            throw NSError(domain: "TTFXMetalExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal device unavailable or invalid cell size"])
        }
        let width = snapshot.columns * cellWidth, height = snapshot.rows * cellHeight
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw NSError(domain: "TTFXMetalExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate export texture"])
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        let size = TTFXMetalDrawableSize(width: Float(width), height: Float(height))
        var submitted: (any MTLCommandBuffer)?
        _ = draw(snapshot: snapshot, cellSize: .init(width: Float(cellWidth), height: Float(cellHeight)), drawableSize: size, logicalSize: size, pass: pass) { submitted = $0 }
        guard let submitted else {
            throw NSError(domain: "TTFXMetalExport", code: 3, userInfo: [NSLocalizedDescriptionKey: lastDrawError ?? "Metal did not submit an export frame"])
        }
        submitted.waitUntilCompleted()
        guard submitted.status == .completed else {
            throw submitted.error ?? NSError(domain: "TTFXMetalExport", code: 4)
        }
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return pixels
    }

    func draw(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize, drawableSize: TTFXMetalDrawableSize, logicalSize: TTFXMetalDrawableSize, pass: MTLRenderPassDescriptor, present: (any MTLCommandBuffer) -> Void) -> TTFXMetalCommandPlan {
        resetDrawState()
        let plan = prepare(snapshot: snapshot, cellSize: cellSize, drawableSize: drawableSize)
        func skipped() -> TTFXMetalCommandPlan {
            TTFXMetalCommandPlan(uploadPlan: plan.uploadPlan, drawableSize: drawableSize, canEncodeGPUCommands: false)
        }
        guard let device, let commandQueue, logicalSize.width > 0, logicalSize.height > 0,
              let target = pass.colorAttachments[0].texture else { return skipped() }
        do {
            if pipeline == nil {
                guard let url = Bundle.module.url(forResource: "GlyphCell", withExtension: "metal", subdirectory: "Shaders") else {
                    throw TTFXMetalResourceError.missingShader
                }
                let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "glyphVertex")
                descriptor.fragmentFunction = library.makeFunction(name: "glyphFragment")
                descriptor.colorAttachments[0].pixelFormat = target.pixelFormat
                pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            }
            let codepoints = Set(snapshot.cells.map(\.codepoint))
            if atlas == nil || !codepoints.isSubset(of: atlas!.codepoints) {
                atlas = try TTFXMetalGlyphAtlas(device: device, codepoints: codepoints.union(atlas?.codepoints ?? []))
            }
            guard let pipeline, let atlas, let commandBuffer = commandQueue.makeCommandBuffer() else { return skipped() }
            let vertices = TTFXMetalVertex.makeVertices(plan: plan.uploadPlan, viewport: logicalSize, atlasRects: atlas.rects)
            guard !vertices.isEmpty, let buffer = vertices.withUnsafeBytes({ bytes in
                device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
            }) else { return skipped() }
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return skipped() }
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setFragmentTexture(atlas.texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
            encoder.endEncoding()
            present(commandBuffer)
            commandBuffer.commit()
            lastEncodedOperationCount = 1
            lastPresentedDrawableSize = drawableSize
            return plan
        } catch {
            lastDrawError = String(describing: error)
            return skipped()
        }
    }

    private func resetDrawState() {
        lastEncodedOperationCount = 0
        lastPresentedDrawableSize = nil
        lastDrawError = nil
    }
    #endif

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
