import Foundation
import Observation

/// Drives the mascot's current frame. The frame index is advanced by a
/// cancellable `Task` loop that sleeps on an injected `Clock`, so the timing
/// source is swappable and the advancement logic stays deterministically
/// testable (call ``advance()`` directly). No `Timer`/`DispatchSourceTimer` and
/// no display link — the loop is cancelled whenever the mascot is hidden.
@MainActor
@Observable
final class MascotAnimator {
    private(set) var clip: MascotClip = .idle
    private(set) var frameIndex: Int = 0

    @ObservationIgnored private let frameDuration: Duration
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var task: Task<Void, Never>?

    init(
        frameDuration: Duration = .milliseconds(150),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.frameDuration = frameDuration
        self.clock = clock
    }

    /// The asset name of the frame to render right now.
    var currentFrameName: String {
        let names = clip.frameNames
        guard !names.isEmpty else { return "" }
        return names[frameIndex % names.count]
    }

    /// Switches clips and restarts that clip from its first frame.
    func setClip(_ clip: MascotClip) {
        guard clip != self.clip else { return }
        self.clip = clip
        frameIndex = 0
    }

    /// Advances one frame, wrapping at the end of the current clip.
    func advance() {
        let count = clip.frameNames.count
        guard count > 0 else { return }
        frameIndex = (frameIndex + 1) % count
    }

    /// Begins the frame loop. Idempotent.
    func start() {
        guard task == nil else { return }
        let clock = clock
        let frameDuration = frameDuration
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: frameDuration)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                self.advance()
            }
        }
    }

    /// Cancels the frame loop. Idempotent.
    func stop() {
        task?.cancel()
        task = nil
    }
}
