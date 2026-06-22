#!/usr/bin/env swift
// Renders the "T-Rex" app icon: a terminal window with a running T-Rex inside.
// Output: a 1024x1024 PNG. Usage: swift generate-trex-icon.swift <out.png>
import AppKit
import Foundation

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "trex-1024.png"
let size = 1024.0

guard let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("could not allocate bitmap") }
rep.size = NSSize(width: size, height: size)

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
  NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// Transparent canvas.
NSColor.clear.set()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// --- App squircle background ------------------------------------------------
let margin = 90.0
let appRect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let appRadius = appRect.width * 0.2237
let appPath = NSBezierPath(roundedRect: appRect, xRadius: appRadius, yRadius: appRadius)
let bgGrad = NSGradient(colors: [color(0.12, 0.15, 0.20), color(0.04, 0.05, 0.07)])!
bgGrad.draw(in: appPath, angle: -90)

// Subtle inner border.
color(1, 1, 1, 0.06).set()
appPath.lineWidth = 4
appPath.stroke()

// --- Terminal window --------------------------------------------------------
let pad = 110.0
let termRect = appRect.insetBy(dx: pad, dy: pad)
let termRadius = 64.0
let termPath = NSBezierPath(roundedRect: termRect, xRadius: termRadius, yRadius: termRadius)
color(0.05, 0.06, 0.08).set()
termPath.fill()

// Title bar (rounded only at top, via clip).
let barH = 96.0
let barRect = NSRect(x: termRect.minX, y: termRect.maxY - barH, width: termRect.width, height: barH)
NSGraphicsContext.saveGraphicsState()
termPath.addClip()
color(0.14, 0.16, 0.20).set()
barRect.fill()
NSGraphicsContext.restoreGraphicsState()

// Traffic-light dots.
let dotR = 20.0
let dotColors = [color(0.99, 0.37, 0.34), color(0.99, 0.74, 0.18), color(0.20, 0.80, 0.35)]
for (i, c) in dotColors.enumerated() {
  let cx = termRect.minX + 56 + Double(i) * 62
  c.set()
  NSBezierPath(ovalIn: NSRect(x: cx - dotR, y: barRect.midY - dotR, width: dotR * 2, height: dotR * 2)).fill()
}

// Body region below the title bar.
let bodyRect = NSRect(x: termRect.minX, y: termRect.minY, width: termRect.width, height: termRect.height - barH)

// --- Speed lines (running motion), drawn behind the dino --------------------
let dino = "🦖" as NSString
let fontSize = 330.0
let dinoAttrs: [NSAttributedString.Key: Any] = [
  .font: NSFont(name: "Apple Color Emoji", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
]
let dSize = dino.size(withAttributes: dinoAttrs)
let dinoX = bodyRect.midX - dSize.width / 2 + 36
let dinoY = bodyRect.midY - dSize.height / 2 - 6

color(0.22, 0.82, 0.45, 0.92).set()
let lineRightX = dinoX - 18
for (i, yo) in [-78.0, 0.0, 78.0].enumerated() {
  let p = NSBezierPath()
  p.lineWidth = 20
  p.lineCapStyle = .round
  let len = (i == 1) ? 150.0 : 104.0
  let y = bodyRect.midY + yo
  p.move(to: NSPoint(x: lineRightX - len, y: y))
  p.line(to: NSPoint(x: lineRightX, y: y))
  p.stroke()
}

// --- T-Rex -----------------------------------------------------------------
dino.draw(at: NSPoint(x: dinoX, y: dinoY), withAttributes: dinoAttrs)

// --- Volcano prompt + cursor at the bottom-left -----------------------------
// The shell prompt is a volcano, in keeping with the prehistoric T-Rex scene.
let volcano = "🌋" as NSString
let volcanoAttrs: [NSAttributedString.Key: Any] = [
  .font: NSFont(name: "Apple Color Emoji", size: 96) ?? NSFont.systemFont(ofSize: 96)
]
let vSize = volcano.size(withAttributes: volcanoAttrs)
let vX = bodyRect.minX + 40
let vY = bodyRect.minY + 34
volcano.draw(at: NSPoint(x: vX, y: vY), withAttributes: volcanoAttrs)
color(0.85, 0.88, 0.92, 0.9).set()
NSBezierPath(rect: NSRect(x: vX + vSize.width + 18, y: vY + 26, width: 70, height: 16)).fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
