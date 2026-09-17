import Testing
import TTFXCore
@testable import TTFXSwiftUI

@Test func frameSnapshotMapsCellsIntoStableRowsAndGlyphs() throws {
    var frame = try Frame(columns: 2, rows: 2)
    frame[column: 1, row: 2] = Cell(codepoint: UInt32(UnicodeScalar("A").value), foreground: 0xff0000, background: 0)
    frame[column: 2, row: 2] = Cell(codepoint: UInt32(UnicodeScalar("B").value), foreground: 0x00ff00, background: 0x101010)
    frame[column: 1, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("C").value), foreground: 0, background: 0x0000ff)

    let snapshot = TTFXFrameSnapshot(frame: frame)

    #expect(snapshot.columns == 2)
    #expect(snapshot.rows == 2)
    #expect(snapshot.cells.map(\.glyph) == ["A", "B", "C", " "])
    #expect(snapshot.cells.map { [$0.column, $0.row] } == [[1, 2], [2, 2], [1, 1], [2, 1]])
    #expect(snapshot.cells[1].foregroundHex == "#00FF00")
    #expect(snapshot.cells[1].backgroundHex == "#101010")
    #expect(snapshot.visibleTextLines == ["AB", "C "])
}

@Test func galleryDemosAreDeterministicAndCoverImplementedEffects() {
    let demos = TTFXGallery.demos

    #expect(demos.count == 37)
    #expect(demos.map(\.id) == demos.map(\.name))
    #expect(demos.map(\.name).prefix(5) == ["beams", "binarypath", "blackhole", "bouncyballs", "bubbles"])
    #expect(demos.map(\.name).suffix(3) == ["waves", "wipe", "print"])
    #expect(Set(demos.map(\.name)).count == demos.count)
    #expect(demos.allSatisfy { !$0.sampleText.isEmpty && $0.canvas.columns >= 12 && $0.canvas.rows >= 6 })
}

@Test func schedulerTicksAtMostOncePerIntervalAndRetainsFrameCapacity() throws {
    var frames = [try Frame(columns: 3, rows: 1), try Frame(columns: 3, rows: 1), try Frame(columns: 3, rows: 1)]
    frames[0][column: 1, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("A").value), foreground: 0, background: 0)
    frames[1][column: 2, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("B").value), foreground: 0, background: 0)
    frames[2][column: 3, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("C").value), foreground: 0, background: 0)
    var index = 0
    var renderer = TTFXDeterministicRenderer(
        frameInterval: .milliseconds(16),
        makeFrame: {
            defer { index += 1 }
            return frames[min(index, frames.count - 1)]
        }
    )

    let first = try renderer.tick(at: .milliseconds(0))
    let skipped = try renderer.tick(at: .milliseconds(15))
    let second = try renderer.tick(at: .milliseconds(16))
    let third = try renderer.tick(at: .milliseconds(48))

    #expect(first.visibleTextLines == ["A  "])
    #expect(skipped.visibleTextLines == ["A  "])
    #expect(second.visibleTextLines == [" B "])
    #expect(third.visibleTextLines == ["  C"])
    #expect(renderer.renderedFrameCount == 3)
    #expect(renderer.lastFrameStorageCapacity == first.storageCapacity)
}

@Test func metalRendererShellReportsHeadlessAvailabilityWithoutDeviceAssumptions() {
    let availability = TTFXMetalRendererAvailability.current

    #expect(!availability.message.isEmpty)
    #expect(availability.isAvailable || availability.message.contains("unavailable"))
}

@Test func metalUploadPlanPacksGlyphCellsInStableRowMajorOrder() throws {
    var frame = try Frame(columns: 2, rows: 1)
    frame[column: 1, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("Z").value), foreground: 0x112233, background: 0x445566)
    frame[column: 2, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("Ω").value), foreground: 0xaabbcc, background: 0)
    let snapshot = TTFXFrameSnapshot(frame: frame)

    let plan = TTFXMetalFrameUploadPlan(snapshot: snapshot, cellSize: TTFXMetalCellSize(width: 8, height: 16))

    #expect(plan.columns == 2)
    #expect(plan.rows == 1)
    #expect(plan.cellCount == 2)
    #expect(plan.byteCount == MemoryLayout<TTFXMetalGlyphCell>.stride * 2)
    #expect(plan.cells.map(\.codepoint) == [UInt32(UnicodeScalar("Z").value), UInt32(UnicodeScalar("Ω").value)])
    #expect(plan.cells.map(\.cellOriginX) == [0, 8])
    #expect(plan.cells.map(\.cellOriginY) == [0, 0])
    #expect(plan.cells[0].foregroundRGB == 0x112233)
    #expect(plan.cells[0].backgroundRGB == 0x445566)
}

@Test func metalCommandPlanIsDeterministicWithoutRequiringAHeadlessGPU() throws {
    var frame = try Frame(columns: 1, rows: 1)
    frame[column: 1, row: 1] = Cell(codepoint: UInt32(UnicodeScalar("M").value), foreground: 0xffffff, background: 0)
    let snapshot = TTFXFrameSnapshot(frame: frame)
    let uploadPlan = TTFXMetalFrameUploadPlan(snapshot: snapshot, cellSize: TTFXMetalCellSize(width: 10, height: 20))

    let commandPlan = TTFXMetalCommandPlan(uploadPlan: uploadPlan, drawableSize: TTFXMetalDrawableSize(width: 10, height: 20), canEncodeGPUCommands: false)

    #expect(commandPlan.operations == [.allocateGlyphCellBuffer(bytes: uploadPlan.byteCount), .uploadGlyphCells(count: 1), .skipGPUEncoding(reason: "Metal device or drawable unavailable in headless test environment")])
    #expect(commandPlan.drawableSize.width == 10)
    #expect(commandPlan.uploadPlan.cells[0].codepoint == UInt32(UnicodeScalar("M").value))
}

#if canImport(MetalKit)
import MetalKit

@Test @MainActor func metalDrawSkipsMissingDrawableWithoutReportingPresentation() throws {
    let renderer = TTFXMetalRenderer(device: nil)
    let view = MTKView(frame: .zero, device: nil)
    let plan = renderer.draw(snapshot: TTFXFrameSnapshot(frame: try Frame(columns: 2, rows: 2)), cellSize: .init(width: 10, height: 20), view: view)
    #expect(plan.operations.last == .skipGPUEncoding(reason: TTFXMetalCommandPlan.headlessSkipReason))
    #expect(renderer.lastPresentedDrawableSize == nil)
    #expect(renderer.lastEncodedOperationCount == 0)
}
#endif

#if canImport(MetalKit)
@Test func metalGeometryKeepsTopRowAboveBottomAndPreservesColors() throws {
    var frame = try Frame(columns: 2, rows: 2)
    frame[column: 1, row: 2] = Cell(codepoint: 65, foreground: 0xff0000, background: 0x112233)
    frame[column: 2, row: 2] = Cell(codepoint: 66, foreground: 0xffffff, background: 0)
    frame[column: 1, row: 1] = Cell(codepoint: 67, foreground: 0xffffff, background: 0)
    let plan = TTFXMetalFrameUploadPlan(snapshot: .init(frame: frame), cellSize: .init(width: 10, height: 20))
    let rects = Dictionary(uniqueKeysWithValues: [UInt32(32), 65, 66, 67].map { ($0, SIMD4<Float>(0, 0, 1, 1)) })
    let vertices = TTFXMetalVertex.makeVertices(plan: plan, viewport: .init(width: 20, height: 40), atlasRects: rects)
    #expect(vertices.count == 24)
    #expect(vertices[0].position == SIMD2(-1, 1)) // A top left
    #expect(vertices[6].position == SIMD2(0, 1)) // B top right
    #expect(vertices[12].position == SIMD2(-1, 0)) // C bottom left
    #expect(vertices[13].position == SIMD2(-1, -1))
    #expect(vertices[0].foreground == 0xff0000)
    #expect(vertices[0].background == 0x112233)
    #expect(MemoryLayout<TTFXMetalVertex>.stride == 24)
}

@Test func metalRendererEncodesAndCommitsOffscreenWhenDeviceExists() throws {
    guard let device = MTLCreateSystemDefaultDevice() else { return }
    let renderer = TTFXMetalRenderer(device: device)
    var frame = try Frame(columns: 2, rows: 2)
    frame[column: 1, row: 2] = Cell(codepoint: 65, foreground: 0xffffff, background: 0x112233)
    frame[column: 2, row: 1] = Cell(codepoint: 937, foreground: 0xff0000, background: 0)
    let snapshot = TTFXFrameSnapshot(frame: frame)
    let size = TTFXMetalDrawableSize(width: 80, height: 112)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 80, height: 112, mipmapped: false)
    descriptor.usage = .renderTarget
    let target = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    var submitted: (any MTLCommandBuffer)?
    var presentationCount = 0
    let plan = renderer.draw(snapshot: snapshot, cellSize: .init(width: 40, height: 56), drawableSize: size, logicalSize: size, pass: pass) { commandBuffer in
        #expect(commandBuffer.status == .notEnqueued)
        submitted = commandBuffer
        presentationCount += 1
    }
    #expect(renderer.lastDrawError == nil)
    let commandBuffer = try #require(submitted)
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    #expect(commandBuffer.error == nil)
    #expect(presentationCount == 1)
    #expect(renderer.lastPresentedDrawableSize == size)
    #expect(renderer.lastEncodedOperationCount == 1)
    #expect(plan.operations.last == .encodeGlyphDraw(count: 4))
    #expect(renderer.lastGlyphCellBufferLength == plan.uploadPlan.byteCount)
}
#endif

#if canImport(MetalKit)
@Test func metalOffscreenPixelsContainBackgroundAndUprightGlyphsAcrossAtlasRows() throws {
    guard let device = MTLCreateSystemDefaultDevice() else { return }
    var frame = try Frame(columns: 20, rows: 2)
    // More than 16 distinct scalars exercises multiple atlas rows.
    for column in 1...20 {
        frame[column: column, row: 2] = Cell(codepoint: UInt32(64 + column), foreground: 0xffffff, background: 0x112233)
    }
    let renderer = TTFXMetalRenderer(device: device)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 800, height: 112, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = .renderTarget
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    var submitted: (any MTLCommandBuffer)?
    let size = TTFXMetalDrawableSize(width: 800, height: 112)
    renderer.draw(snapshot: .init(frame: frame), cellSize: .init(width: 40, height: 56), drawableSize: size, logicalSize: size, pass: pass) { submitted = $0 }
    try #require(submitted).waitUntilCompleted()
    #expect(renderer.lastDrawError == nil)
    var pixels = [UInt8](repeating: 0, count: 800 * 112 * 4)
    texture.getBytes(&pixels, bytesPerRow: 800 * 4, from: MTLRegionMake2D(0, 0, 800, 112), mipmapLevel: 0)
    for column in 0..<20 {
        let coverage = (0..<56).reduce(0) { total, y in
            total + (0..<40).filter { x in pixels[(y * 800 + column * 40 + x) * 4 + 2] > 150 }.count
        }
        #expect(coverage > 30, "Missing glyph in column \(column)")
    }
    #expect(Array(pixels[0..<3]) == [0x33, 0x22, 0x11])
    // Row 1 is blank black; the glyph row must remain above it.
    #expect(pixels[(90 * 800 + 20) * 4 + 2] == 0)
    // F has two arms above its stem: upper-half coverage exceeds lower-half.
    let upper = (0..<28).reduce(0) { total, y in total + (0..<40).filter { x in pixels[(y * 800 + 5 * 40 + x) * 4 + 2] > 150 }.count }
    let lower = (28..<56).reduce(0) { total, y in total + (0..<40).filter { x in pixels[(y * 800 + 5 * 40 + x) * 4 + 2] > 150 }.count }
    #expect(upper > lower)
}
#endif
