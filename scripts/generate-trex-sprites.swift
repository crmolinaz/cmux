#!/usr/bin/env swift
// Generates the T-Rex mascot sprite frames (pixel-art, logo-styled green Rex on
// a transparent background) for the CmuxMascot package. Each frame is rendered
// from a character grid with nearest-neighbor blocks so it scales up crisply.
//
// Usage: swift generate-trex-sprites.swift <output-dir>
import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Packages/macOS/CmuxMascot/Sources/CmuxMascot/Resources"
let cell = 16.0  // pixels per grid cell

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
let bodyColor = color(0.36, 0.84, 0.33)   // logo green
let shadeColor = color(0.20, 0.62, 0.22)  // darker green (belly/legs accent)
let eyeColor = color(0.04, 0.10, 0.05)    // near-black eye

// Static body of the Rex (head top-right, tail left, tiny arm). '#'=body,
// 's'=shade, 'O'=eye, '.'=empty. Bottom leg rows are appended per frame.
let body: [String] = [
    "............######..",
    "...........#OO#####.",
    "...........#OO#####.",
    "...........########.",
    "...........#####....",
    "...........#####....",
    "#..........#####....",
    "##.........######...",
    "###.......#######...",
    "####.....########...",
    "#####...#########...",
    "######.##########...",
    "################....",
    ".###############....",
    "..#####ssss#####....",
    "...####ssss####.....",
    "....##########......",
]

// Leg rows (width 20). Two legs under the body (cols ~4-5 and ~8-9).
let legsStand = [
    "....##...##.........",
    "....##...##.........",
    "....ss...ss.........",
]
let legsRunA = [  // front leg forward, back leg trailing
    "....##....##........",
    "...##......##.......",
    "..ss........ss......",
]
let legsRunB = [  // back leg forward, front leg trailing
    ".....##..##.........",
    ".....##..##.........",
    ".....ss..ss.........",
]

func frameGrid(legs: [String], blink: Bool, liftRows: Int) -> [String] {
    var rows = body
    if blink {
        rows = rows.map { row in
            String(row.map { $0 == "O" ? "#" : $0 })  // close eye -> body fill
        }
    }
    rows.append(contentsOf: legs)
    // Vertical bob: prepend empty rows on top to "lift" the sprite.
    let width = rows.first?.count ?? 0
    let empty = String(repeating: ".", count: width)
    var lifted = Array(repeating: empty, count: max(0, liftRows))
    lifted.append(contentsOf: rows)
    // Keep total height constant across frames (pad bottom).
    let targetHeight = body.count + 3 + 2  // body + legs + max lift headroom
    while lifted.count < targetHeight { lifted.append(empty) }
    return lifted
}

func render(_ grid: [String], to path: String) {
    let cols = grid.map { $0.count }.max() ?? 0
    let rowsN = grid.count
    let w = Int(Double(cols) * cell)
    let h = Int(Double(rowsN) * cell)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("alloc") }
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: w, height: h).fill()
    for (r, row) in grid.enumerated() {
        for (c, ch) in row.enumerated() {
            let fill: NSColor?
            switch ch {
            case "#": fill = bodyColor
            case "s": fill = shadeColor
            case "O": fill = eyeColor
            default: fill = nil
            }
            guard let fill else { continue }
            fill.set()
            // Row 0 is the top of the sprite; flip for AppKit's bottom-left origin.
            let x = Double(c) * cell
            let y = Double(rowsN - 1 - r) * cell
            NSRect(x: x, y: y, width: cell, height: cell).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(w)x\(h))")
}

let frames: [(String, [String])] = [
    ("trex-idle-0", frameGrid(legs: legsStand, blink: false, liftRows: 2)),
    ("trex-idle-1", frameGrid(legs: legsStand, blink: false, liftRows: 1)),
    ("trex-run-0",  frameGrid(legs: legsRunA,  blink: false, liftRows: 1)),
    ("trex-run-1",  frameGrid(legs: legsStand, blink: false, liftRows: 0)),
    ("trex-run-2",  frameGrid(legs: legsRunB,  blink: false, liftRows: 1)),
    ("trex-blink-0", frameGrid(legs: legsStand, blink: true,  liftRows: 2)),
]

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, grid) in frames {
    render(grid, to: "\(outDir)/\(name).png")
}
print("done")
