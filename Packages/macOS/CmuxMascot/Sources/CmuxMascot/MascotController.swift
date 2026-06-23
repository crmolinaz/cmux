import Foundation
public import Observation

/// Public entry point for the T-Rex mascot.
///
/// The mascot is an embedded strip (see ``MascotStripView``) rather than a
/// window: the controller just holds visibility + the animation state. The app
/// target owns a single instance (the composition root) and embeds the strip
/// above its project tabs — there is deliberately no shared singleton, so the
/// module stays free of app-global state and is easy to lift elsewhere.
///
/// Future hearts/quest behavior attaches here: a `MascotState` value plus a
/// hydration-quest loop (the same cancellable `Task`/`Clock` primitive the
/// animator uses) would hang off this controller without touching the app.
@MainActor
@Observable
public final class MascotController {
    /// Whether the mascot strip should be shown. Observed by the host so the
    /// strip appears/disappears reactively.
    public private(set) var isVisible: Bool = false

    let animator: MascotAnimator

    public init() {
        self.animator = MascotAnimator()
        MascotSprite.preload()
    }

    /// Shows the mascot: it runs in, then settles into an idle loop.
    public func show() {
        guard !isVisible else { return }
        isVisible = true
        animator.setClip(.run)
        animator.start()
        Task { [weak animator] in
            try? await Task.sleep(for: .milliseconds(1200))
            animator?.setClip(.idle)
        }
    }

    /// Hides the mascot and stops the animation loop.
    public func hide() {
        guard isVisible else { return }
        isVisible = false
        animator.stop()
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}
