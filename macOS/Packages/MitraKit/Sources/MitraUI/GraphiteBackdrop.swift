import SwiftUI
import MitraKit

/// The night sky behind the AC in the panel and the widgets: a graphite mesh, lighter where
/// the air comes out and fading to near black at the bottom. The same in every mode (the air
/// carries the mode's colour), dimmer while the AC is off, and slowly drifting when animated.
public struct GraphiteBackdrop: View {
    let isOn: Bool
    let animated: Bool

    public init(isOn: Bool, animated: Bool = true) {
        self.isOn = isOn
        self.animated = animated
    }

    public var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: !isOn)) { context in
                    mesh(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                mesh(time: 0)
            }
        }
        .animation(.easeInOut(duration: 1.4), value: isOn)
    }

    private func mesh(time t: TimeInterval) -> some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [Float(0.5 + 0.12 * sin(t * 0.21)), Float(0.42 + 0.1 * cos(t * 0.17))], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: colors)
    }

    private var colors: [Color] {
        let tint = ACMode.fan.tint, glow = ACMode.fan.glow
        let night = Color(red: 0.03, green: 0.04, blue: 0.08)
        let dim = isOn ? 0.0 : 0.08
        return [
            tint.mix(with: night, by: 0.72 + dim), glow.mix(with: night, by: 0.62 + dim), tint.mix(with: night, by: 0.8 + dim),
            tint.mix(with: night, by: 0.78 + dim), tint.mix(with: night, by: 0.55 + dim), glow.mix(with: night, by: 0.82 + dim),
            night, tint.mix(with: night, by: 0.9), night,
        ]
    }
}
