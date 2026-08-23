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
