import Foundation
import CoreGraphics
import CoreText

/// Replays the Rust terminal's ANSI frames through CoreText, not the Swift effect engine.
final class ANSIRasterizer {
    let columns: Int, rows: Int
    let width: Int, height: Int
    private let font = CTFontCreateWithName("Menlo" as CFString, 20, nil)
    private var glyphCache: [String: CTLine] = [:]
    init(columns: Int, rows: Int) {
        self.columns = columns; self.rows = rows; width = columns * 16; height = rows * 24
    }
    func pixels(_ frame: String) throws -> Data {
        let bitmap = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmap) else { throw CaptureError.message("Cannot create ANSI bitmap") }
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        var foreground: UInt32 = 0xffffff, background: UInt32 = 0
        var bold = false, inverse = false, column = 0, row = 0
        let scalars = Array(frame.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar.value == 27, index + 1 < scalars.count, scalars[index + 1] == "[" {
                var end = index + 2
                while end < scalars.count, !(0x40...0x7e).contains(scalars[end].value) { end += 1 }
                guard end < scalars.count else { throw CaptureError.message("Incomplete ANSI escape") }
                if scalars[end] == "m" {
                    let raw = String(String.UnicodeScalarView(scalars[(index + 2)..<end]))
                    let params = raw.isEmpty ? [0] : raw.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
                    var p = 0
                    while p < params.count {
                        let code = params[p]
                        switch code {
                        case 0: foreground = 0xffffff; background = 0; bold = false; inverse = false
                        case 1: bold = true
                        case 22: bold = false
                        case 7: inverse = true
                        case 27: inverse = false
                        case 39: foreground = 0xffffff
                        case 49: background = 0
                        case 30...37: foreground = Self.xterm(code - 30)
                        case 40...47: background = Self.xterm(code - 40)
                        case 90...97: foreground = Self.xterm(code - 90 + 8)
                        case 100...107: background = Self.xterm(code - 100 + 8)
                        case 38, 48:
                            var value: UInt32?
                            if p + 4 < params.count, params[p + 1] == 2 {
                                value = UInt32(params[p + 2] << 16 | params[p + 3] << 8 | params[p + 4]); p += 4
                            } else if p + 2 < params.count, params[p + 1] == 5 {
                                value = Self.xterm(params[p + 2]); p += 2
                            }
                            if let value { if code == 38 { foreground = value } else { background = value } }
                        default: break
                        }
                        p += 1
                    }
                } else { throw CaptureError.message("Unexpected control sequence in Rust parity output") }
                index = end + 1; continue
            }
            if scalar == "\n" { row += 1; column = 0; index += 1; continue }
            if scalar == "\r" { column = 0; index += 1; continue }
            if row < rows, column < columns {
                let fg = inverse ? background : foreground, bg = inverse ? foreground : background
                let rect = CGRect(x: column * 16, y: height - (row + 1) * 24, width: 16, height: 24)
                context.setFillColor(Self.color(bg)); context.fill(rect)
                if scalar != " " {
                    let key = "\(scalar.value)-\(fg)-\(bold)"
                    let line: CTLine
                    if let cached = glyphCache[key] { line = cached }
                    else {
                        let drawFont = bold ? (CTFontCreateCopyWithSymbolicTraits(font, 20, nil, .traitBold, .traitBold) ?? font) : font
                        let attributes: [CFString: Any] = [kCTFontAttributeName: drawFont, kCTForegroundColorAttributeName: Self.color(fg)]
                        let string = CFAttributedStringCreate(nil, String(scalar) as CFString, attributes as CFDictionary)!
                        line = CTLineCreateWithAttributedString(string); glyphCache[key] = line
                    }
                    context.saveGState(); context.clip(to: rect)
                    context.textPosition = CGPoint(x: rect.minX + 1, y: rect.minY + 5)
                    CTLineDraw(line, context); context.restoreGState()
                }
            }
            column += 1; index += 1
        }
        return Data(bytes: context.data!, count: width * height * 4)
    }
    private static func color(_ rgb: UInt32) -> CGColor {
        CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [Double((rgb >> 16) & 255) / 255, Double((rgb >> 8) & 255) / 255, Double(rgb & 255) / 255, 1])!
    }
    private static func xterm(_ n: Int) -> UInt32 {
        let standard: [UInt32] = [0x000000,0x800000,0x008000,0x808000,0x000080,0x800080,0x008080,0xc0c0c0,0x808080,0xff0000,0x00ff00,0xffff00,0x0000ff,0xff00ff,0x00ffff,0xffffff]
        if n < 16 { return standard[max(0, n)] }
        if n >= 232 { let gray = UInt32(min(255, 8 + (n - 232) * 10)); return gray * 0x010101 }
        let c = n - 16, levels: [UInt32] = [0,95,135,175,215,255]
        return levels[(c / 36) % 6] << 16 | levels[(c / 6) % 6] << 8 | levels[c % 6]
    }
}
