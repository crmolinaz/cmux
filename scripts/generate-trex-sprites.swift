#!/usr/bin/env swift
// Renders the T-Rex mascot frames for the CmuxMascot package from a baked pixel
// matrix (traced from the reference art), with lengthened legs, an idle bob, and
// an eye-closed "wink" frame. Self-contained — no external image dependency.
//
// Usage: swift generate-trex-sprites.swift <output-dir>
import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Packages/macOS/CmuxMascot/Sources/CmuxMascot/Resources"
let scale = 16
let padTop = 8

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: 1)
}
// Palette. The reference's near-identical light greens (2/4/5) are merged.
let outline = rgb(31, 92, 52)
let medium = rgb(74, 148, 64)
let light = rgb(132, 176, 72)
let cream = rgb(226, 198, 118)
func color(_ ch: Character) -> NSColor? {
    switch ch {
    case "1": return medium
    case "2", "4", "5": return light
    case "3": return cream
    case "6": return outline
    default: return nil
    }
}

// Traced matrix (18 wide). '.' = transparent. '6'=outline, '1'=body, '3'=belly.
let baseRows = [
    "........66666.....",
    ".......65555566...",
    "......65555555566.",
    "......655566555426",
    ".....6154566554626",
    ".....6155545554426",
    ".....6115446454226",
    "66....61144466666.",
    "626...6111443346..",
    "646..6454166666...",
    "6446614544636.....",
    "61421444642626....",
    ".6122444166366....",
    ".611644446336.....",
    "..6161442636......",
    "...6611161616.....",
    ".....66666666.....",
]
let width = baseRows.map { $0.count }.max() ?? 0
func padded(_ s: String) -> String {
    s.count < width ? s + String(repeating: ".", count: width - s.count) : s
}

// Lengthen the legs: insert two leg rows above the foot row (left cols 5-7,
// right cols 9-11, outline on the outer edges).
let legRow: String = {
    var a = Array(repeating: Character("."), count: width)
    for c in [5, 6, 7] { a[c] = "1" }
    for c in [9, 10, 11] { a[c] = "1" }
    a[5] = "6"; a[7] = "6"; a[9] = "6"; a[11] = "6"
    return String(a)
}()
var rows = baseRows.map(padded)
let foot = rows.removeLast()
rows.append(legRow)
rows.append(legRow)
rows.append(foot)
let height = rows.count

// Sleeping pose: the dino lying on the grass, eyes closed, drawn at the bottom
// of the same canvas so it swaps in without a size jump and sits low (napping).
let sleepDino = [
    "......6666......",
    "....66111166....",
    "..661111111166..",
    ".61111111111116.",
    "61111166111111116",
    "61113331111111116",
    "61133331111111116",
    "66111111111111116",
    ".661111111111166.",
    "..66666666666666.",
].map(padded)
let sleepGrid: [String] = {
    let topPad = height - sleepDino.count
    let empty = String(repeating: ".", count: width)
    return Array(repeating: empty, count: max(0, topPad)) + sleepDino
}()

enum EyeState { case normal, closed, squint }

func render(_ source: [String], eye: EyeState, lift: Int, to path: String) {
    var grid = source.map(Array.init)
    switch eye {
    case .normal:
        break
    case .closed:
        for (j, i) in [(3, 10), (3, 11), (4, 10), (4, 11)] { grid[j][i] = "5" }
    case .squint:
        // Drop the top row of the eye so it reads as a smaller, half-open eye.
        for (j, i) in [(3, 10), (3, 11)] { grid[j][i] = "5" }
    }
    let cw = width * scale
    let ch = height * scale + padTop * 2
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
    let yoff = padTop - lift
    for (j, row) in grid.enumerated() {
        for (i, ch2) in row.enumerated() {
            guard let col = color(ch2) else { continue }
            col.set()
            let yTop = j * scale + yoff
            // Row 0 is the sprite's top; flip for AppKit's bottom-left origin.
            let y = ch - (yTop + scale)
            NSRect(x: i * scale, y: y, width: scale, height: scale).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(cw)x\(ch))")
}

// Yawn: standing, eyes closed, mouth opened wide (dark cavity carved into the
// snout) — shown briefly when waking up.
let yawnGrid: [String] = {
    var g = rows.map(Array.init)
    for (j, i) in [(5, 14), (5, 15), (6, 14), (6, 15), (6, 16), (7, 14), (7, 15)] {
        if j < g.count, i < g[j].count { g[j][i] = "6" }
    }
    return g.map { String($0) }
}()

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
render(rows, eye: .normal, lift: 0, to: "\(outDir)/trex-idle-0.png")
render(rows, eye: .normal, lift: 6, to: "\(outDir)/trex-idle-1.png")
render(rows, eye: .closed, lift: 0, to: "\(outDir)/trex-blink-0.png")
render(sleepGrid, eye: .normal, lift: 0, to: "\(outDir)/trex-sleep-0.png")
render(sleepGrid, eye: .normal, lift: 2, to: "\(outDir)/trex-sleep-1.png")
render(yawnGrid, eye: .squint, lift: 0, to: "\(outDir)/trex-yawn-0.png")
print("done")
