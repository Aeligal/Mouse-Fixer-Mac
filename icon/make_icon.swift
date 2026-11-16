import Cocoa
// usage: make_icon <out.iconset dir>
func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bg = NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88), xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(colors: [NSColor(red: 0.30, green: 0.55, blue: 1.0, alpha: 1), NSColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1)])!.draw(in: bg, angle: -60)
    // mouse body
    let body = NSBezierPath(roundedRect: NSRect(x: s * 0.31, y: s * 0.18, width: s * 0.38, height: s * 0.64), xRadius: s * 0.19, yRadius: s * 0.19)
    NSColor.white.setFill(); body.fill()
    // split line + wheel
    NSColor(white: 0, alpha: 0.18).setStroke()
    let split = NSBezierPath(); split.move(to: NSPoint(x: s * 0.5, y: s * 0.82)); split.line(to: NSPoint(x: s * 0.5, y: s * 0.62))
    split.lineWidth = s * 0.012; split.stroke()
    let wheel = NSBezierPath(roundedRect: NSRect(x: s * 0.468, y: s * 0.60, width: s * 0.064, height: s * 0.14), xRadius: s * 0.032, yRadius: s * 0.032)
    NSColor(red: 0.30, green: 0.45, blue: 0.95, alpha: 1).setFill(); wheel.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
let dir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (name, px) in [("16", 16), ("16@2x", 32), ("32", 32), ("32@2x", 64), ("128", 128), ("128@2x", 256), ("256", 256), ("256@2x", 512), ("512", 512), ("512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(dir)/icon_\(name.replacingOccurrences(of: "@2x", with: ""))\(name.contains("@2x") ? "@2x" : "").png".replacingOccurrences(of: "icon_\(name.replacingOccurrences(of: "@2x", with: ""))", with: "icon_\(name.replacingOccurrences(of: "@2x", with: ""))x\(name.replacingOccurrences(of: "@2x", with: ""))")))
}
