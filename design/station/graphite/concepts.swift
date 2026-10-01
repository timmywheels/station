// Station app icon concepts, riffing on the in-app glyph (a rounded square hatched with 45° lines).
// Run: swift design/station/icon-concepts/concepts.swift
// Writes, next to this file: <name>.icns, <name>-1024.png per concept, and concepts-sheet.png.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

struct Concept {
    let name: String, title: String
    let tileTop: CGColor, tileBottom: CGColor
    let ink: CGColor                 // the glyph's frame
    let stripes: [CGColor]           // top-left first; one per stripe
    let glyphScale: CGFloat          // glyph size as a share of the tile
    let framed: Bool                 // false: the tile itself is the glyph's frame
    let well: CGColor?               // fill inside the frame, behind the stripes
}

let red = rgb(0xff453a), yellow = rgb(0xffd60a), green = rgb(0x30d158)
let concepts: [Concept] = [
    Concept(name: "graphite", title: "1 · Graphite",
            tileTop: rgb(0x3b3f47), tileBottom: rgb(0x121417), ink: rgb(0xffffff), stripes: [rgb(0xffffff)],
            glyphScale: 0.56, framed: true, well: nil),
    Concept(name: "graphite-light", title: "1 · Graphite, light",
            tileTop: rgb(0xffffff), tileBottom: rgb(0xd9dade), ink: rgb(0x1a1c20), stripes: [rgb(0x1a1c20)],
            glyphScale: 0.56, framed: true, well: nil),
    Concept(name: "signal", title: "2 · Signal",
            tileTop: rgb(0x2f3239), tileBottom: rgb(0x0d0e10), ink: rgb(0xffffff), stripes: [red, yellow, green],
            glyphScale: 0.56, framed: true, well: nil),
    Concept(name: "indigo", title: "3 · Indigo",
            tileTop: rgb(0x6e74ff), tileBottom: rgb(0x3b2fd0), ink: rgb(0xffffff), stripes: [rgb(0xffffff)],
            glyphScale: 0.56, framed: true, well: rgb(0xffffff, 0.12)),
    Concept(name: "bold", title: "4 · Bold",
            tileTop: rgb(0xfdfdfd), tileBottom: rgb(0xdedfe3), ink: rgb(0xffffff), stripes: [rgb(0xffffff)],
            glyphScale: 0.0, framed: false, well: nil),
]

/// The in-app glyph: a rounded square frame with three 45° lines clipped inside it.
/// Heavier strokes at small pixel sizes so it holds at 16 and 32 px.
func glyph(_ ctx: CGContext, _ r: CGRect, frameInk: CGColor, stripes: [CGColor], well: CGColor?, px: CGFloat, frame: Bool = true) {
    let s = r.width
    let heavy = px <= 32 ? 1.35 : px <= 64 ? 1.15 : 1.0
    let fw = s * 0.085 * heavy         // frame width
    let sw = s * 0.095 * heavy         // stripe width
    let gap = s * 0.25                 // stripe pitch, along the normal
    let radius = s * 0.24
    let inner = r.insetBy(dx: fw, dy: fw)
    ctx.saveGState()
    let innerPath = CGPath(roundedRect: inner, cornerWidth: radius - fw, cornerHeight: radius - fw, transform: nil)
    if let well { ctx.addPath(innerPath); ctx.setFillColor(well); ctx.fillPath() }
    ctx.addPath(innerPath); ctx.clip()
    let c = CGPoint(x: r.midX, y: r.midY), q = CGFloat(0.5).squareRoot()
    ctx.setLineWidth(sw); ctx.setLineCap(.butt)
    // At 16 and 32 px three lines blur into a checkerboard: draw fewer, further apart.
    let ks: [CGFloat] = px <= 16 ? [0] : px <= 32 ? [-0.62, 0.62] : [-1, 0, 1] // 16 px: one slash
    for (i, k) in ks.enumerated() {
        // Lines run bottom left to top right; k = -1 is the top-left one.
        let o = CGPoint(x: c.x + k * gap * q, y: c.y - k * gap * q)
        ctx.setStrokeColor(stripes[i % stripes.count])
        ctx.move(to: CGPoint(x: o.x - s, y: o.y - s)); ctx.addLine(to: CGPoint(x: o.x + s, y: o.y + s))
        ctx.strokePath()
    }
    ctx.restoreGState()
    if frame {
        ctx.addPath(CGPath(roundedRect: r.insetBy(dx: fw / 2, dy: fw / 2), cornerWidth: radius - fw / 2, cornerHeight: radius - fw / 2, transform: nil))
        ctx.setStrokeColor(frameInk); ctx.setLineWidth(fw); ctx.strokePath()
    }
}

/// A full macOS icon on a `px` canvas: 824/1024 body, Apple's corner radius, a soft drop shadow.
func icon(_ c: Concept, px: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let u = CGFloat(px) / 1024
    let body = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let tile = CGPath(roundedRect: body, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)

    // Shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 28 * u, color: rgb(0x000000, 0.35))
    ctx.addPath(tile); ctx.setFillColor(c.tileBottom); ctx.fillPath()
    ctx.restoreGState()

    // Tile: vertical gradient, then a faint top sheen.
    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    let g = CGGradient(colorsSpace: srgb, colors: [c.tileTop, c.tileBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
    let sheen = CGGradient(colorsSpace: srgb, colors: [rgb(0xffffff, 0.10), rgb(0xffffff, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.midY), options: [])

    if c.framed {
        let gs = 824 * u * (px <= 32 ? 0.70 : c.glyphScale) // bigger glyph where pixels are scarce
        let gr = CGRect(x: body.midX - gs / 2, y: body.midY - gs / 2, width: gs, height: gs)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6 * u), blur: 18 * u, color: rgb(0x000000, c.tileTop == rgb(0xffffff) ? 0.12 : 0.30))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        glyph(ctx, gr, frameInk: c.ink, stripes: c.stripes, well: c.well, px: CGFloat(px))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    } else {
        // Bold: a light tile with a dark rounded well inset in it, white lines across the well.
        let well = body.insetBy(dx: 150 * u, dy: 150 * u)
        let wellPath = CGPath(roundedRect: well, cornerWidth: 120 * u, cornerHeight: 120 * u, transform: nil)
        ctx.saveGState()
        ctx.addPath(wellPath); ctx.clip()
        let wg = CGGradient(colorsSpace: srgb, colors: [rgb(0x2a2d33), rgb(0x0b0c0e)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(wg, start: CGPoint(x: 0, y: well.maxY), end: CGPoint(x: 0, y: well.minY), options: [])
        ctx.restoreGState()
        // Inner shadow along the well's top edge, so it reads as cut in.
        ctx.saveGState()
        ctx.addPath(wellPath); ctx.clip()
        let ring = CGMutablePath(); ring.addRect(well.insetBy(dx: -60 * u, dy: -60 * u)); ring.addPath(wellPath)
        ctx.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 16 * u, color: rgb(0x000000, 0.8))
        ctx.addPath(ring); ctx.setFillColor(rgb(0x000000)); ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
        // The glyph's lines and frame, sized to the well: the well is the frame's inside.
        let fw = well.width * 0.085
        glyph(ctx, well.insetBy(dx: -fw, dy: -fw), frameInk: rgb(0xffffff), stripes: c.stripes, well: nil, px: CGFloat(px), frame: false)
    }
    ctx.restoreGState()
    return ctx.makeImage()!
}

func write(_ img: CGImage, to url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}

// 1. Per concept: a 1024 PNG and an .icns built from a hand-rendered iconset (each size drawn, not scaled).
let fm = FileManager.default
for c in concepts {
    write(icon(c, px: 1024), to: out.appendingPathComponent("\(c.name)-1024.png"))
    let set = out.appendingPathComponent("\(c.name).iconset")
    try? fm.removeItem(at: set); try! fm.createDirectory(at: set, withIntermediateDirectories: true)
    for pt in [16, 32, 128, 256, 512] {
        write(icon(c, px: pt), to: set.appendingPathComponent("icon_\(pt)x\(pt).png"))
        write(icon(c, px: pt * 2), to: set.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
    }
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    p.arguments = ["-c", "icns", set.path, "-o", out.appendingPathComponent("\(c.name).icns").path]
    try! p.run(); p.waitUntilExit()
    try? fm.removeItem(at: set)
    print("wrote \(c.name).icns")
}

// 2. Contact sheet: each concept large, then at Dock (128), Finder list (32) and 16 px, on light and dark.
let col = 560, sheetW = col * concepts.count, sheetH = 1000
let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.interpolationQuality = .none
sheet.setFillColor(rgb(0xececee)); sheet.fill(CGRect(x: 0, y: 500, width: sheetW, height: 500))
sheet.setFillColor(rgb(0x1e1f22)); sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: 500))
func label(_ s: String, _ p: CGPoint, _ color: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
    (s as NSString).draw(at: p, withAttributes: [.font: NSFont.systemFont(ofSize: 28, weight: .semibold), .foregroundColor: color])
    NSGraphicsContext.restoreGraphicsState()
}
for (i, c) in concepts.enumerated() {
    let x = CGFloat(i * col)
    sheet.draw(icon(c, px: 400), in: CGRect(x: x + 80, y: 560, width: 400, height: 400))
    label(c.title, CGPoint(x: x + 80, y: 520), NSColor(white: 0.1, alpha: 1))
    // Dark row: real pixel sizes, shown 2x (nearest neighbour) so the pixels are visible: 128, 32, 16.
    var cx = x + 40
    for pt in [128, 32, 16] {
        let img = icon(c, px: pt * 2) // @2x, as on a Retina Dock
        sheet.draw(img, in: CGRect(x: cx, y: 250 - CGFloat(pt) / 2, width: CGFloat(pt), height: CGFloat(pt)))
        cx += CGFloat(pt) + 40
    }
    sheet.draw(icon(c, px: 16), in: CGRect(x: x + 40, y: 60, width: 128, height: 128)) // 16 px blown up 8x
    sheet.draw(icon(c, px: 32), in: CGRect(x: x + 200, y: 60, width: 128, height: 128)) // 32 px blown up 4x
    label("16 px ×8      32 px ×4", CGPoint(x: x + 40, y: 16), NSColor(white: 0.85, alpha: 1))
}
write(sheet.makeImage()!, to: out.appendingPathComponent("concepts-sheet.png"))
print("wrote concepts-sheet.png")
