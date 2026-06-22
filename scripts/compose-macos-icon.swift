#!/usr/bin/env swift
// Composites a full-bleed square artwork onto the standard macOS icon grid:
// scaled into the 824px content area of a 1024px canvas, masked to the macOS
// squircle, with a subtle drop shadow. Usage:
//   swift compose-macos-icon.swift <in.png> <out.png>
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count > 2 else { fatalError("usage: compose-macos-icon.swift <in.png> <out.png>") }
let inPath = args[1]
let outPath = args[2]

let canvas = 1024.0
let inset = 100.0                 // standard margin around the icon
let content = canvas - 2 * inset  // 824
let radius = content * 0.2237     // macOS rounded-rect corner radius

guard let src = NSImage(contentsOfFile: inPath) else { fatalError("cannot read \(inPath)") }

guard let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("alloc failed") }
rep.size = NSSize(width: canvas, height: canvas)

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

NSColor.clear.set()
NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

let rect = NSRect(x: inset, y: inset, width: content, height: content)
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

// Drop shadow cast by the silhouette.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor.black.set()
path.fill()
NSGraphicsContext.restoreGraphicsState()

// Clip to the squircle and draw the artwork scaled into the content rect.
NSGraphicsContext.saveGraphicsState()
path.addClip()
src.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
