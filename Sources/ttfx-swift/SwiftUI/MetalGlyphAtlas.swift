#if canImport(MetalKit)
import CoreText
import Foundation
import MetalKit

struct TTFXMetalVertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
    var foreground: UInt32
    var background: UInt32

    static func makeVertices(plan: TTFXMetalFrameUploadPlan, viewport: TTFXMetalDrawableSize, atlasRects: [UInt32: SIMD4<Float>]) -> [Self] {
        var result: [Self] = []
        result.reserveCapacity(plan.cellCount * 6)
        for cell in plan.cells {
            guard let rect = atlasRects[cell.codepoint] else { continue }
            // TTE row 1 is the bottom row. Anchor the canvas at the view's top.
            let left = cell.cellOriginX / viewport.width * 2 - 1
            let right = (cell.cellOriginX + plan.cellSize.width) / viewport.width * 2 - 1
            let top = 1 - (Float(plan.rows) * plan.cellSize.height - cell.cellOriginY - plan.cellSize.height) / viewport.height * 2
            let bottom = top - plan.cellSize.height / viewport.height * 2
            let positions: [SIMD2<Float>] = [.init(left, top), .init(left, bottom), .init(right, bottom), .init(left, top), .init(right, bottom), .init(right, top)]
            let uvs: [SIMD2<Float>] = [.init(rect.x, rect.y), .init(rect.x, rect.w), .init(rect.z, rect.w), .init(rect.x, rect.y), .init(rect.z, rect.w), .init(rect.z, rect.y)]
            for index in positions.indices {
                result.append(Self(position: positions[index], uv: uvs[index], foreground: cell.foregroundRGB, background: cell.backgroundRGB))
            }
        }
        return result
    }
}

struct TTFXMetalGlyphAtlas {
    let codepoints: Set<UInt32>
    let rects: [UInt32: SIMD4<Float>]
    let texture: any MTLTexture
    enum AtlasError: Error { case allocationFailed }

    init(device: any MTLDevice, codepoints: Set<UInt32>) throws {
        self.codepoints = codepoints
        let slotWidth = 40, slotHeight = 56, columns = 16
        let width = slotWidth * columns
        let height = max(1, (codepoints.count + columns - 1) / columns) * slotHeight
        var pixels = [UInt8](repeating: 0, count: width * height)
        var mapped: [UInt32: SIMD4<Float>] = [:]
        let font = CTFontCreateWithName("Menlo" as CFString, 44, nil)
        try pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { throw AtlasError.allocationFailed }
            context.setFillColor(gray: 1, alpha: 1)
            for (index, codepoint) in codepoints.sorted().enumerated() {
                let x = (index % columns) * slotWidth, y = (index / columns) * slotHeight
                let text = UnicodeScalar(codepoint).map(String.init) ?? "�"
                let string = NSAttributedString(string: text, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
                ])
                let line = CTLineCreateWithAttributedString(string)
                let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                let descent = CGFloat(CTFontGetDescent(font))
                context.saveGState()
                context.clip(to: CGRect(x: x, y: y, width: slotWidth, height: slotHeight))
                context.textPosition = CGPoint(x: CGFloat(x) + (CGFloat(slotWidth) - advance) / 2, y: CGFloat(y) + descent + 2)
                CTLineDraw(line, context)
                context.restoreGState()
                // Bitmap scanlines run from top to bottom, Quartz text is upright.
                mapped[codepoint] = SIMD4(Float(x) / Float(width), Float(height - y - slotHeight) / Float(height), Float(x + slotWidth) / Float(width), Float(height - y) / Float(height))
            }
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw AtlasError.allocationFailed }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width)
        self.texture = texture
        self.rects = mapped
    }
}
#endif
