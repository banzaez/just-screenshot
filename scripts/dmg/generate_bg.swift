#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let widthPt: CGFloat = 600
let heightPt: CGFloat = 400
let args = Array(CommandLine.arguments.dropFirst())
let scale: CGFloat = args.contains("--1x") ? 1.0 : 2.0
let widthPx = Int(widthPt * scale)
let heightPx = Int(heightPt * scale)

let outputPath = args.first(where: { !$0.hasPrefix("--") }) ?? "scripts/dmg/background.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: widthPx,
    height: heightPx,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

// Flip coordinate system to top-left origin in points
ctx.scaleBy(x: scale, y: scale)
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

// 1. Background linear gradient (deep slate -> midnight indigo)
let bgColors = [
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.15, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.23, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.17, alpha: 1.0).cgColor
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.5, 1.0]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: widthPt, y: heightPt),
        options: []
    )
}

// 2. Subtle ambient radial glow behind center
let glowColors = [
    NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.96, alpha: 0.16).cgColor,
    NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.96, alpha: 0.0).cgColor
] as CFArray
if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: widthPt / 2, y: 195),
        startRadius: 0,
        endCenter: CGPoint(x: widthPt / 2, y: 195),
        endRadius: 260,
        options: []
    )
}

// 3. Subtle drop-zone cards behind icon positions (165, 184) and (435, 184)
// In bottom-left CG coords (height = 400):
// Top-left card y = 108..284  =>  bottom-left y = 116..292 (center = 204)
func drawSlotCard(centerX: CGFloat) {
    let cardRect = CGRect(x: centerX - 82, y: 116, width: 164, height: 176)
    let path = NSBezierPath(roundedRect: cardRect, xRadius: 24, yRadius: 24)
    NSColor(calibratedWhite: 1.0, alpha: 0.045).setFill()
    path.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
    path.lineWidth = 1.0
    path.stroke()
}
drawSlotCard(centerX: 165)
drawSlotCard(centerX: 435)

// 4. Crisp vector arrow in the center (aligned with icon center y=184 from top => y=216 from bottom)
let arrowY: CGFloat = 216
let arrowPath = NSBezierPath()
arrowPath.lineWidth = 4.0
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: CGPoint(x: 264, y: arrowY))
arrowPath.line(to: CGPoint(x: 334, y: arrowY))
arrowPath.move(to: CGPoint(x: 318, y: arrowY - 14))
arrowPath.line(to: CGPoint(x: 336, y: arrowY))
arrowPath.line(to: CGPoint(x: 318, y: arrowY + 14))

NSColor(calibratedRed: 0.42, green: 0.72, blue: 1.0, alpha: 0.95).setStroke()
arrowPath.stroke()

// 5. Header & helper labels (drawn via AppKit in flipped coordinates)
// Note: CGContext has origin at bottom-left, so invert y for NSString.draw
func drawCenteredText(_ text: String, yFromTop: CGFloat, font: NSFont, color: NSColor) {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: para
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    let size = str.size()
    // Flip back temporarily for NSAttributedString drawing
    ctx.saveGState()
    ctx.translateBy(x: 0, y: heightPt)
    ctx.scaleBy(x: 1, y: -1)
    let rect = CGRect(x: 0, y: yFromTop, width: widthPt, height: size.height + 4)
    str.draw(in: rect)
    ctx.restoreGState()
}

// Since ctx was scaled & flipped above, let's check orientation:
// Actually ctx had no flip; nsCtx was created with flipped: true, which only affects NSGraphicsContext,
// while CGContextDrawLinearGradient used unflipped coords. So drawCenteredText's translate/scale flips twice!
// Let's keep it simple: draw text in unflipped NSGraphicsContext or test once and inspect!
NSGraphicsContext.restoreGraphicsState()

let unflippedNsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = unflippedNsCtx

func drawText(_ text: String, yFromBottom: CGFloat, font: NSFont, color: NSColor) {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: para
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    let rect = CGRect(x: 0, y: yFromBottom, width: widthPt, height: 40)
    str.draw(in: rect)
}

drawText(
    "Just Screenshot",
    yFromBottom: 332,
    font: NSFont.systemFont(ofSize: 22, weight: .semibold),
    color: NSColor(calibratedWhite: 1.0, alpha: 0.95)
)
drawText(
    "Drag the app into Applications to install",
    yFromBottom: 302,
    font: NSFont.systemFont(ofSize: 13, weight: .regular),
    color: NSColor(calibratedRed: 0.68, green: 0.74, blue: 0.84, alpha: 0.95)
)
drawText(
    "After copying, launch from Applications or Spotlight",
    yFromBottom: 24,
    font: NSFont.systemFont(ofSize: 11, weight: .regular),
    color: NSColor(calibratedRed: 0.55, green: 0.60, blue: 0.70, alpha: 0.85)
)

NSGraphicsContext.restoreGraphicsState()

guard let cgImage = ctx.makeImage() else {
    fputs("Failed to make CGImage\n", stderr)
    exit(1)
}

let outURL = URL(fileURLWithPath: outputPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(outURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("Failed to create CGImageDestination\n", stderr)
    exit(1)
}
let dpi = Int(72.0 * scale)
let props: [CFString: Any] = [
    kCGImagePropertyDPIWidth: dpi,
    kCGImagePropertyDPIHeight: dpi
]
CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
if !CGImageDestinationFinalize(dest) {
    fputs("Failed to finalize PNG\n", stderr)
    exit(1)
}
print("Generated \(outputPath) (\(widthPx)x\(heightPx) @ 144 DPI)")
