// Renders DuoDevOverlayDemo's 1024×1024 app icon (opaque, as the App Store requires).
// Usage: swift Tools/make-icon.swift DuoDevOverlayDemo/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let s = CGFloat(size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, a])!
}

// Flip so y grows downward, like the app's coordinates.
ctx.translateBy(x: 0, y: s)
ctx.scaleBy(x: 1, y: -1)

// Background: deep navy vertical gradient.
let bg = CGGradient(colorsSpace: space, colors: [rgb(34, 46, 84), rgb(14, 20, 40)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: 0, y: s), options: [])

// The device's inner display, landscape-ish and slightly wider than tall.
let screen = CGRect(x: 152, y: 222, width: 720, height: 580)
let screenPath = CGPath(roundedRect: screen, cornerWidth: 64, cornerHeight: 64, transform: nil)

// Soft drop shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: rgb(0, 0, 0, 0.45))
ctx.addPath(screenPath)
ctx.setFillColor(rgb(232, 232, 236))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(screenPath)
ctx.clip()

// Bottom inset band (home indicator) and trailing inset band (status bar).
ctx.setFillColor(rgb(120, 172, 228, 0.75))
ctx.fill(CGRect(x: screen.minX, y: screen.maxY - 56, width: screen.width, height: 56))
let trailing = CGRect(x: screen.maxX - 112, y: screen.minY, width: 112, height: screen.height)
ctx.fill(trailing)

// Fold: faint orange band with a dashed centre line.
let foldX = screen.midX - 56
ctx.setFillColor(rgb(255, 149, 0, 0.18))
ctx.fill(CGRect(x: foldX - 26, y: screen.minY, width: 52, height: screen.height))
ctx.setStrokeColor(rgb(255, 149, 0))
ctx.setLineWidth(12)
ctx.setLineCap(.round)
ctx.setLineDash(phase: 0, lengths: [34, 26])
ctx.move(to: CGPoint(x: foldX, y: screen.minY + 30))
ctx.addLine(to: CGPoint(x: foldX, y: screen.maxY - 30))
ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])

// Camera / status block: magenta occlusion region at the top of the band.
let camera = CGRect(x: trailing.minX + 18, y: screen.minY + 28, width: trailing.width - 36, height: 150)
let cameraPath = CGPath(roundedRect: camera, cornerWidth: 22, cornerHeight: 22, transform: nil)
ctx.addPath(cameraPath)
ctx.setFillColor(rgb(255, 45, 85, 0.35))
ctx.fillPath()
ctx.addPath(cameraPath)
ctx.setStrokeColor(rgb(255, 45, 85))
ctx.setLineWidth(10)
ctx.strokePath()

ctx.restoreGState()

// Thin bezel outline.
ctx.addPath(screenPath)
ctx.setStrokeColor(rgb(255, 255, 255, 0.35))
ctx.setLineWidth(6)
ctx.strokePath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
precondition(CGImageDestinationFinalize(dest), "failed to write PNG")
print("wrote \(url.path)")
