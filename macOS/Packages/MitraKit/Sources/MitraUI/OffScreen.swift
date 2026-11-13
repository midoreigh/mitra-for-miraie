import SwiftUI

public extension EnvironmentValues {
    /// True while the view can't be seen, such as when the menu bar panel is closed. The animated
    /// AC and backdrop hold still, so a hidden panel costs no CPU.
    @Entry var isOffScreen = false
}

/// Animation time that stands still while the animation is paused: when it resumes, it carries
/// on from where it stopped instead of catching up on the time it missed.
@MainActor
final class AnimationClock {
    private var last: TimeInterval?
    private var skipped = 0.0

    func time(at now: TimeInterval) -> TimeInterval {
        // A frame normally follows within a fraction of a second; a longer gap was a pause.
        if let last, now - last > 0.25 { skipped += now - last - 1.0 / 40 }
        last = now
        return now - skipped
    }
}
