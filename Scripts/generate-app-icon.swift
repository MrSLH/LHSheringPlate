import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = CGSize(width: 1024, height: 1024)
let rect = CGRect(origin: .zero, size: size)

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: 220, yRadius: 220)
let backgroundGradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.31, alpha: 1.0),
        NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.50, alpha: 1.0),
    ]
)!
backgroundGradient.draw(in: backgroundPath, angle: -45)

NSColor(calibratedWhite: 1.0, alpha: 0.09).setFill()
NSBezierPath(ovalIn: CGRect(x: 118, y: 652, width: 320, height: 180)).fill()

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.18)
shadow.shadowBlurRadius = 32
shadow.shadowOffset = CGSize(width: 0, height: -12)
shadow.set()

let rearCard = NSBezierPath(roundedRect: CGRect(x: 292, y: 248, width: 420, height: 500), xRadius: 72, yRadius: 72)
NSColor(calibratedRed: 0.78, green: 0.88, blue: 0.85, alpha: 0.82).setFill()
rearCard.fill()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let frontShadow = NSShadow()
frontShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.22)
frontShadow.shadowBlurRadius = 40
frontShadow.shadowOffset = CGSize(width: 0, height: -14)
frontShadow.set()

let frontCard = NSBezierPath(roundedRect: CGRect(x: 230, y: 170, width: 500, height: 620), xRadius: 88, yRadius: 88)
NSColor(calibratedRed: 0.97, green: 0.94, blue: 0.88, alpha: 1.0).setFill()
frontCard.fill()

let clipHead = NSBezierPath(roundedRect: CGRect(x: 366, y: 698, width: 228, height: 118), xRadius: 48, yRadius: 48)
NSColor(calibratedRed: 0.93, green: 0.63, blue: 0.27, alpha: 1.0).setFill()
clipHead.fill()

let clipInner = NSBezierPath(roundedRect: CGRect(x: 416, y: 726, width: 128, height: 52), xRadius: 24, yRadius: 24)
NSColor(calibratedRed: 0.99, green: 0.90, blue: 0.78, alpha: 0.94).setFill()
clipInner.fill()

let lineColor = NSColor(calibratedRed: 0.14, green: 0.31, blue: 0.35, alpha: 0.95)
lineColor.setFill()
NSBezierPath(roundedRect: CGRect(x: 302, y: 560, width: 356, height: 44), xRadius: 22, yRadius: 22).fill()
NSBezierPath(roundedRect: CGRect(x: 302, y: 458, width: 298, height: 44), xRadius: 22, yRadius: 22).fill()
NSBezierPath(roundedRect: CGRect(x: 302, y: 356, width: 334, height: 44), xRadius: 22, yRadius: 22).fill()

let accent = NSBezierPath()
accent.move(to: CGPoint(x: 606, y: 278))
accent.line(to: CGPoint(x: 704, y: 376))
accent.line(to: CGPoint(x: 650, y: 430))
accent.line(to: CGPoint(x: 552, y: 332))
accent.close()
NSColor(calibratedRed: 0.93, green: 0.63, blue: 0.27, alpha: 1.0).setFill()
accent.fill()

let smallAccent = NSBezierPath(roundedRect: CGRect(x: 332, y: 254, width: 168, height: 36), xRadius: 18, yRadius: 18)
NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.60, alpha: 1.0).setFill()
smallAccent.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG data\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outputURL, options: .atomic)
