import AppKit
import Foundation

/// The mascot's animation clips. Each clip is an ordered list of authored frame
/// images bundled with the package (see `scripts/generate-trex-sprites.swift`).
enum MascotClip: CaseIterable {
    case idle
    case blink
    case sleep
    case yawn

    /// Frame asset basenames, in playback order. `idle`/`sleep` gently bob,
    /// `blink` is the tap wink, `yawn` plays once on waking.
    var frameNames: [String] {
        switch self {
        case .idle: return ["trex-idle-0", "trex-idle-1"]
        case .blink: return ["trex-blink-0"]
        case .sleep: return ["trex-sleep-0", "trex-sleep-1"]
        case .yawn: return ["trex-yawn-0"]
        }
    }
}

/// Loads and caches the mascot's frame images from the package bundle.
@MainActor
enum MascotSprite {
    private static var cache: [String: NSImage] = [:]

    /// Every distinct frame name across all clips, in first-seen order.
    static var allFrameNames: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for clip in MascotClip.allCases {
            for name in clip.frameNames where seen.insert(name).inserted {
                ordered.append(name)
            }
        }
        return ordered
    }

    /// Eagerly load every frame so the render path never touches disk.
    static func preload() {
        for name in allFrameNames where cache[name] == nil {
            if let image = load(name) { cache[name] = image }
        }
    }

    static func image(named name: String) -> NSImage? {
        cache[name] ?? load(name)
    }

    private static func load(_ name: String) -> NSImage? {
        guard let url = bundledURL(forFrame: name) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Resolves a frame's bundled URL. `nonisolated` so tests can assert every
    /// declared frame ships in the package without hopping to the main actor.
    nonisolated static func bundledURL(forFrame name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png")
    }
}
