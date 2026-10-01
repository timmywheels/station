// Station's "Graphite" app icon art: the in-app glyph (a rounded square hatched with three 45° lines)
// on a graphite tile, full-bleed 1024 px, dark and light. scripts/make-app-icon.sh turns these into
// Station/AppIcon.icon (Icon Composer masks, lights and shades them).
// Run: swift design/station/graphite/graphite-art.swift  (writes next to this file)
import AppKit
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

struct Look { let name: String; let top: CGColor; let bottom: CGColor; let ink: CGColor; let glyphShadow: CGFloat }
let looks = [
    Look(name: "dark", top: rgb(0x3b3f47), bottom: rgb(0x121417), ink: rgb(0xffffff), glyphShadow: 0.30),
    Look(name: "light", top: rgb(0xffffff), bottom: rgb(0xd9dade), ink: rgb(0x1a1c20), glyphShadow: 0.12),
]

/// The glyph: a rounded square frame with three 45° lines (bottom left to top right) clipped inside it.
func glyph(_ ctx: CGContext, _ r: CGRect, ink: CGColor) {
    let s = r.width, fw = s * 0.085, sw = s * 0.095, gap = s * 0.25, radius = s * 0.24
    let q = CGFloat(0.5).squareRoot(), c = CGPoint(x: r.midX, y: r.midY)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r.insetBy(dx: fw, dy: fw), cornerWidth: radius - fw, cornerHeight: radius - fw, transform: nil)); ctx.clip()
    ctx.setLineWidth(sw); ctx.setStrokeColor(ink)
    for k: CGFloat in [-1, 0, 1] {
        let o = CGPoint(x: c.x + k * gap * q, y: c.y - k * gap * q)
        ctx.move(to: CGPoint(x: o.x - s, y: o.y - s)); ctx.addLine(to: CGPoint(x: o.x + s, y: o.y + s)); ctx.strokePath()
    }
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: r.insetBy(dx: fw / 2, dy: fw / 2), cornerWidth: radius - fw / 2, cornerHeight: radius - fw / 2, transform: nil))
    ctx.setStrokeColor(ink); ctx.setLineWidth(fw); ctx.strokePath()
}

for look in looks {
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let g = CGGradient(colorsSpace: srgb, colors: [look.top, look.bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 1024), end: .zero, options: [])
    let gs: CGFloat = 1024 * 0.56
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: rgb(0x000000, look.glyphShadow))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    glyph(ctx, CGRect(x: 512 - gs / 2, y: 512 - gs / 2, width: gs, height: gs), ink: look.ink)
    ctx.endTransparencyLayer()
    let url = out.appendingPathComponent("station-graphite-\(look.name)-art-1024.png")
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
    print("wrote \(url.lastPathComponent)")
}
