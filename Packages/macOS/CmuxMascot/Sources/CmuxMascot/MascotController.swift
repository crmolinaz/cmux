import AppKit
import Foundation
public import Observation

/// Public entry point for the T-Rex mascot.
///
/// The mascot is an embedded strip (see ``MascotStripView``); the controller
/// holds visibility, the animation state, and a small mood state machine:
/// after ``idleTimeout`` with no typing it falls asleep (lying in the grass with
/// floating "zzz"); typing or a tap wakes it with a yawn, then back to idle.
///
/// The app target owns a single instance (the composition root) and embeds the
/// strip above its project tabs — there is deliberately no shared singleton, so
/// the module stays free of app-global state and is easy to lift elsewhere.
@MainActor
@Observable
public final class MascotController {
    public enum Mood: Sendable {
        case idle
        case asleep
        case yawning
    }

    /// Whether the mascot strip should be shown.
    public private(set) var isVisible: Bool = false
    /// Current mood; drives the pose and the "zzz".
    public private(set) var mood: Mood = .idle

    /// How long without typing before the mascot naps. Configurable; defaults
    /// to one minute.
    public var idleTimeout: Duration = .seconds(60)
    /// How long the waking yawn plays before returning to idle.
    public var yawnDuration: Duration = .milliseconds(1100)

    public var isAsleep: Bool { mood == .asleep }

    let animator: MascotAnimator
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var idleSeconds: Int = 0
    @ObservationIgnored private var idleWatch: Task<Void, Never>?
    @ObservationIgnored private var keyMonitor: Any?

    public init(clock: any Clock<Duration> = ContinuousClock()) {
        self.clock = clock
        self.animator = MascotAnimator(clock: clock)
        MascotSprite.preload()
    }

    public func show() {
        guard !isVisible else { return }
        isVisible = true
        mood = .idle
        idleSeconds = 0
        animator.setClip(.idle)
        animator.start()
        startIdleWatch()
        installKeyMonitor()
    }

    public func hide() {
        guard isVisible else { return }
        isVisible = false
        animator.stop()
        idleWatch?.cancel()
        idleWatch = nil
        removeKeyMonitor()
    }

    public func toggle() {
        if isVisible { hide() } else { show() }
    }

    /// Registers user activity (typing). Resets the idle timer and wakes the
    /// mascot if it was asleep.
    public func noteActivity() {
        idleSeconds = 0
        if mood == .asleep { wake() }
    }

    /// A tap on the mascot: wake it if asleep, otherwise wink.
    public func poke() {
        switch mood {
        case .asleep: noteActivity()
        case .idle: idleSeconds = 0; wink()
        case .yawning: idleSeconds = 0
        }
    }

    /// Briefly closes the eye (a wink) then returns to idle.
    public func wink() {
        guard isVisible, mood == .idle else { return }
        animator.setClip(.blink)
        let clock = clock
        Task { [weak self] in
            try? await clock.sleep(for: .milliseconds(220))
            guard let self, self.mood == .idle else { return }
            self.animator.setClip(.idle)
        }
    }

    // MARK: - Mood transitions

    private func fallAsleep() {
        guard mood == .idle else { return }
        mood = .asleep
        animator.setClip(.sleep)
    }

    private func wake() {
        guard mood == .asleep else { return }
        mood = .yawning
        idleSeconds = 0
        animator.setClip(.yawn)
        let clock = clock
        let duration = yawnDuration
        Task { [weak self] in
            try? await clock.sleep(for: duration)
            guard let self, self.mood == .yawning else { return }
            self.mood = .idle
            self.animator.setClip(.idle)
        }
    }

    // MARK: - Idle watch

    private func startIdleWatch() {
        idleWatch?.cancel()
        let clock = clock
        idleWatch = Task { [weak self] in
            while !Task.isCancelled {
                do { try await clock.sleep(for: .seconds(1)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.tickIdle()
            }
        }
    }

    private func tickIdle() {
        guard mood == .idle else { return }
        idleSeconds += 1
        if idleSeconds >= Int(idleTimeout.components.seconds) {
            fallAsleep()
        }
    }

    // MARK: - Typing monitor

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.noteActivity() }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
