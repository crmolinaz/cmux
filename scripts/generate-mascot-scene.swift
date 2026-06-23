#!/usr/bin/env swift
// Renders the mascot scenery pixel elements for the CmuxMascot strip: a volcano
// (anchored bottom-right) and a trees+pond cluster (anchored bottom-left). The
// sky and grass are drawn in SwiftUI so the strip fills any width.
//
// Usage: swift generate-mascot-scene.swift <output-dir>
import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Packages/macOS/CmuxMascot/Sources/CmuxMascot/Resources"
let scale = 8

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: 1)
}

func render(_ rows: [String], palette: [Character: NSColor], to path: String) {
    let width = rows.map { $0.count }.max() ?? 0
    let cw = width * scale
    let ch = rows.count * scale
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: cw, pixelsHigh: ch,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("alloc") }
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: cw, height: ch).fill()
    for (j, row) in rows.enumerated() {
        for (i, ch2) in row.enumerated() {
            guard let col = palette[ch2] else { continue }
            col.set()
            let y = ch - ((j * scale) + scale)  // flip: row 0 at top
            NSRect(x: i * scale, y: y, width: scale, height: scale).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(cw)x\(ch))")
}

// --- Volcano: smoke puff, lava crater with a drip, two-tone rock body. ---
let volcano = [
    ".....S..........",
    "....SSS.........",
    "...SSSSS........",
    "....SSS.........",
    ".....S..........",
    "................",
    ".....LLLL.......",
    "....RLLLLR......",
    "....RLllLR......",
    "...RrLllLLR.....",
    "...RrRLLloRR....",
    "..RrrRRRloRRR...",
    "..RrrRRRRloRR...",
    ".RrrrRRRRRoRR...",
    ".RrrRRRRRRRrRR..",
    "RrrrRRRRRRRRrRR.",
    "RrrRRRRRRRRRRrRR",
]
let volcanoPalette: [Character: NSColor] = [
    "R": rgb(92, 74, 66),    // rock dark
    "r": rgb(126, 106, 94),  // rock light (lit left face)
    "L": rgb(255, 104, 40),  // lava bright
    "l": rgb(255, 182, 52),  // lava glow
    "o": rgb(255, 138, 46),  // lava drip
    "S": rgb(214, 214, 214), // smoke
]

// --- Trees: two leafy trees with trunks planted on the ground (trunk at the
// bottom so they sit on the grass, not float). ---
let trees = [
    "...DD......DD....",
    "..DDDD....DDDD...",
    ".DDGDDD..DDGDDD..",
    ".DDDDDD..DDDDDD..",
    "..DDDD....DDDD...",
    "...TT......TT....",
    "...TT......TT....",
    "...TT......TT....",
]
let treesPalette: [Character: NSColor] = [
    "D": rgb(46, 124, 58),   // leaf dark
    "G": rgb(108, 184, 84),  // leaf highlight
    "T": rgb(120, 78, 46),   // trunk
]

// --- Pond: a separate small pool that sits in the foreground grass. ---
let pond = [
    "...wwwwwww...",
    ".wWWWWWWWWWw.",
    ".wWWwWWWWWWw.",
    "..wWWWWWWWw..",
    "...wwwwwww...",
]
let pondPalette: [Character: NSColor] = [
    "W": rgb(74, 168, 212),  // water
    "w": rgb(158, 214, 236), // water highlight
]

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
render(volcano, palette: volcanoPalette, to: "\(outDir)/scene-volcano.png")
render(trees, palette: treesPalette, to: "\(outDir)/scene-trees.png")
render(pond, palette: pondPalette, to: "\(outDir)/scene-pond.png")
print("done")
