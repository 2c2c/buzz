// Renders the app icon as a 1024 px PNG.  Usage: swift Scripts/make-icon.swift OUTPUT.png
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let size = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("could not create bitmap")
}
NSGraphicsContext.current = graphics
let cg = graphics.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

// Background: the standard macOS icon tile (824 pt square on a 1024 canvas).
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
cg.saveGState()
cg.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
cg.clip()
let background = CGGradient(
    colorsSpace: space,
    colors: [color(0.20, 0.22, 0.34), color(0.07, 0.07, 0.13)] as CFArray,
    locations: [0, 1]
)!
cg.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
cg.restoreGState()

// Vibration arcs either side of the trackpad.
let center = CGPoint(x: 512, y: 512)
cg.setLineCap(.round)
cg.setLineWidth(36)
for (radius, alpha) in [(262.0, 1.0), (338.0, 0.5)] {
    cg.setStrokeColor(color(1.0, 0.74, 0.28, alpha))
    let spread = CGFloat.pi * 0.16
    cg.addArc(center: center, radius: radius, startAngle: -spread, endAngle: spread, clockwise: false)
    cg.strokePath()
    cg.addArc(center: center, radius: radius, startAngle: .pi - spread, endAngle: .pi + spread, clockwise: false)
    cg.strokePath()
}

// Trackpad.
let pad = CGRect(x: 512 - 180, y: 512 - 130, width: 360, height: 260)
let padPath = CGPath(roundedRect: pad, cornerWidth: 46, cornerHeight: 46, transform: nil)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0, 0, 0, 0.5))
cg.addPath(padPath)
cg.setFillColor(color(0.9, 0.91, 0.94))
cg.fillPath()
cg.restoreGState()

cg.saveGState()
cg.addPath(padPath)
cg.clip()
let padGradient = CGGradient(
    colorsSpace: space,
    colors: [color(0.97, 0.97, 0.99), color(0.78, 0.80, 0.86)] as CFArray,
    locations: [0, 1]
)!
cg.drawLinearGradient(padGradient, start: CGPoint(x: 512, y: pad.maxY), end: CGPoint(x: 512, y: pad.minY), options: [])
cg.restoreGState()

graphics.flushGraphics()
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("could not encode PNG") }
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
