import SwiftUI
import MitraKit

/// Where the louvers point at a moment in time, in degrees. Fixed positions map to fixed
/// angles; swing sweeps continuously, the way the real louvers do.
public struct LouverAngles: Equatable, Sendable {
    /// Below horizontal: about 12° (level, blowing at you) to 72° (straight down).
    public var vertical: Double
    /// Left (negative) to right (positive).
    public var horizontal: Double

    public init(vertical: Double, horizontal: Double) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    public init(state: ACState, time: TimeInterval) {
        // Real louvers swing slowly: about 18 s for a full up-down-up sweep and 22 s for
        // left-right-left.
        vertical = state.verticalLouver == Louver.swing
            ? 42 + 28 * sin(time * 2 * .pi / 18)
            : Self.vertical(state.verticalLouver)
        horizontal = state.horizontalLouver == Louver.swing
            ? 30 * sin(time * 2 * .pi / 22 + 1)
            : Self.horizontal(state.horizontalLouver)
    }

    public static func vertical(_ position: Int) -> Double { 12 + Double(position - 1) * 15 }
    public static func horizontal(_ position: Int) -> Double { Double(Louver.horizontalSlot(position) - 3) * 17 }
}

/// The indoor unit seen from the front, with air streaming out that follows both louvers:
/// the vertical louver sets how far down the air goes, the horizontal one steers it left or
/// right, and swing animates either. The air's colour follows the mode and its speed the fan.
public struct ACUnitView: View {
    let state: ACState
    let animated: Bool
    let statusLight: Color?
    let statusText: String?
    let onStatusLightTap: (() -> Void)?
    @State private var motion = AirMotion()

    /// - Parameters:
    ///   - statusLight: The colour of the light on the unit, e.g. to show whether it's online.
    ///     Without one, the light shows green while the AC runs with its display on.
    ///   - statusText: What the light means, shown when hovering it.
    ///   - onStatusLightTap: Makes the light clickable.
    public init(state: ACState, animated: Bool = true, statusLight: Color? = nil, statusText: String? = nil,
                onStatusLightTap: (() -> Void)? = nil) {
        self.state = state
        self.animated = animated
        self.statusLight = statusLight
        self.statusText = statusText
        self.onStatusLightTap = onStatusLightTap
    }

    public var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1 / 40, paused: !state.isOn)) { context in
                ACUnitScene(state: state, time: context.date.timeIntervalSinceReferenceDate,
                            statusLight: statusLight, statusText: statusText, onStatusLightTap: onStatusLightTap,
                            motion: motion)
            }
        } else {
            // Widgets can't animate: show the airflow mid-stream.
            ACUnitScene(state: state, time: 1.3, statusLight: statusLight, statusText: statusText)
        }
    }
}

/// Carries the animation from one frame to the next, so changes ease in rather than jump:
/// the louvers travel to a new position at a brisk but visible pace (faster than they swing),
/// and each bit of air keeps the fan speed and mode it left the unit with, so a change flows
/// out from the outlet instead of the whole room changing at once.
@MainActor
final class AirMotion {
    /// Degrees per second when moving to a new position; swinging tops out near 10.
    private static let louverSpeed = 40.0

    private var vertical: Double?
    private var horizontal: Double?
    private var lastTime: TimeInterval?
    private var air: [AirParticle] = []
    private var airTime: TimeInterval?
    /// For each stream, progress towards releasing its next bit of air, and how far apart (on
    /// average 1) the next release is, so the air comes out irregularly rather than in rows.
    private var release: [Double] = []
    private var gap: [Double] = []
    private var released = 0

    func angles(for state: ACState, at time: TimeInterval) -> LouverAngles {
        let target = LouverAngles(state: state, time: time)
        // A long gap (the animation was paused) shouldn't turn into one big jump.
        let elapsed = lastTime.map { min(0.1, max(0, time - $0)) } ?? 0
        lastTime = time
        let step = Self.louverSpeed * elapsed
        func approach(_ current: Double?, _ goal: Double) -> Double {
            guard let current else { return goal }
            return current + min(step, max(-step, goal - current))
        }
        let next = LouverAngles(vertical: approach(vertical, target.vertical),
                                horizontal: approach(horizontal, target.horizontal))
        vertical = next.vertical
        horizontal = next.horizontal
        return next
    }

    /// Moves every bit of air along at its own speed, and releases new air from the outlet at
    /// the current fan speed, carrying the current mode. Air already in the room carries on as it
    /// left until it fades, so a change starts at the outlet straight away and flows outward.
    func air(for state: ACState, at time: TimeInterval) -> [AirParticle] {
        if release.isEmpty {
            air = AirflowCanvas.steadyAir(state: state, time: time)
            release = (0..<AirflowCanvas.streams).map { AirflowCanvas.noise($0 * 13 + 5) }
            gap = (0..<AirflowCanvas.streams).map { 0.4 + 1.2 * AirflowCanvas.noise($0 * 29 + 3) }
        }
        // A long gap (the animation was paused) shouldn't turn into one big jump.
        let elapsed = airTime.map { min(0.1, max(0, time - $0)) } ?? 0
        airTime = time
        let speed = AirflowCanvas.speed(fan: state.fan, time: time)

        for index in air.indices { air[index].progress += air[index].speed * elapsed }
        air.removeAll { $0.progress >= 1 }

        // At a steady speed each stream holds `particlesPerStream` bits of air, as before.
        let perStream = Double(AirflowCanvas.particlesPerStream)
        for stream in release.indices {
            release[stream] += speed * elapsed * perStream
            while release[stream] >= gap[stream] {
                release[stream] -= gap[stream]
                released += 1
                let seed = AirflowCanvas.noise(released * 17 + stream)
                gap[stream] = 0.4 + 1.2 * AirflowCanvas.noise(released * 23 + stream * 7)
                // Already a little way out if it was due part-way through this frame; each bit
                // travels a touch faster or slower than the next.
                air.append(AirParticle(stream: stream, seed: seed,
                                       progress: release[stream] / perStream, speed: speed * (0.9 + 0.2 * seed),
                                       fan: state.fan, mode: state.mode))
            }
        }
        return air
    }
}

/// One bit of air on its way from the outlet: which stream it's in, how far it has gone (0 to
/// 1), how fast it travels, and the fan speed and mode it left the unit with, which set its
/// colour and whether it sinks or rises.
struct AirParticle {
    let stream: Int
    /// Varies its brightness, so the air doesn't look uniform.
    let seed: Double
    var progress: Double
    var speed: Double
    var fan: FanSpeed
    var mode: ACMode
}

/// One frame of `ACUnitView`.
public struct ACUnitScene: View {
    /// The unit's width as a share of the scene's; the air fans out across the rest.
    static let unitWidth = 0.64
    let state: ACState
    let time: TimeInterval
    let statusLight: Color?
    let statusText: String?
    let onStatusLightTap: (() -> Void)?
    let motion: AirMotion?

    public init(state: ACState, time: TimeInterval, statusLight: Color? = nil, statusText: String? = nil,
                onStatusLightTap: (() -> Void)? = nil) {
        self.init(state: state, time: time, statusLight: statusLight, statusText: statusText,
                  onStatusLightTap: onStatusLightTap, motion: nil)
    }

    init(state: ACState, time: TimeInterval, statusLight: Color?, statusText: String?,
         onStatusLightTap: (() -> Void)?, motion: AirMotion?) {
        self.state = state
        self.time = time
        self.statusLight = statusLight
        self.statusText = statusText
        self.onStatusLightTap = onStatusLightTap
        self.motion = motion
    }

    public var body: some View {
        let angles = motion?.angles(for: state, at: time) ?? LouverAngles(state: state, time: time)
        let air = motion?.air(for: state, at: time) ?? AirflowCanvas.steadyAir(state: state, time: time)
        GeometryReader { geo in
            let unitHeight = min(geo.size.height * 0.34, geo.size.width * Self.unitWidth / 3.9)
            VStack(spacing: 0) {
                UnitBody(state: state, angles: angles, statusLight: statusLight, statusText: statusText,
                         onStatusLightTap: onStatusLightTap)
                    .frame(width: geo.size.width * Self.unitWidth, height: unitHeight)
                    .zIndex(1) // the open flap hangs over the start of the air
                AirflowCanvas(state: state, angles: angles, time: time, air: air)
                    .frame(width: geo.size.width)
                    .opacity(state.isOn ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6), value: state.isOn)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// The casing, its display and status light, and the flap along the bottom.
struct UnitBody: View {
    let state: ACState
    let angles: LouverAngles
    let statusLight: Color?
    let statusText: String?
    let onStatusLightTap: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .top) {
                UnitShell(isOn: state.isOn, angles: angles)
                    .shadow(color: .black.opacity(0.35), radius: size.height * 0.18, y: size.height * 0.1)

                UnitDisplay(state: state, hint: displayHint)
                    .frame(height: size.height * 0.3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, size.width * 0.05)
                    .padding(.top, size.height * 0.14)

                let light = statusLight ?? (state.isOn && state.display ? Color.green : nil)
                StatusLight(color: light ?? .clear, diameter: size.height * 0.09)
                    .opacity(light == nil ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: light)
                    // A target bigger than the light itself, so it's easy to hover.
                    .frame(width: 22, height: 22)
                    .contentShape(.rect)
                    .onTapGesture { onStatusLightTap?() }
                    .allowsHitTesting(statusText != nil || onStatusLightTap != nil)
                    .hoverHint(statusText ?? "", edge: .trailing, isShown: statusText != nil)
                    .padding(-8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, size.width * 0.06)
                    .padding(.top, size.height * 0.245)
            }
        }
    }
}

extension UnitBody {
    var displayHint: String {
        guard state.isOn else { return "Off" }
        return state.mode.usesSetpoint ? "Set to \(ACState.format(state.setpoint))" : "Fan only"
    }
}

/// The casing and its flap, like a real split unit: the flap is the lower front strip of the
/// casing, flush and closed while the AC is off. Running, it swings away from the casing to
/// open the outlet behind it: level, it shows its whole face and hangs a little below the
/// unit; pointing down, it's seen almost edge-on, a thin blade with a wide gap above it.
struct UnitShell: View {
    let isOn: Bool
    let angles: LouverAngles

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let radius = h * 0.28
            let seam = h * 0.76          // where the front panel meets the flap
            let cap = w * 0.06           // the casing's end caps, either side of the flap
            let strip = h - seam         // the flap's height when closed

            // 1 when the flap is level (seen from below, its whole face shows), 0 when it points
            // straight down (seen almost edge-on, with the outlet wide open above it).
            let level = 1 - min(1, max(0, (angles.vertical - 12) / 60))
            let gap = isOn ? h * (0.15 - 0.07 * level) : 0
            let face = isOn ? strip * (0.4 + 0.75 * level) : strip

            let casing = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: radius, style: .continuous)
            context.fill(casing, with: .linearGradient(Gradient(colors: [Color(white: 0.99), Color(white: 0.87)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

            // The outlet: dark where the flap has moved away, with the left/right vanes in it.
            let outlet = CGRect(x: cap, y: seam, width: w - 2 * cap, height: h - seam)
            var cavity = context
            cavity.clip(to: casing)
            cavity.fill(Path(outlet), with: .color(Color(white: 0.14)))
            if isOn {
                let lean = tan(angles.horizontal * .pi / 180) * gap * 1.2
                var vanes = Path()
                for index in 1..<12 {
                    let x = outlet.minX + outlet.width * Double(index) / 12
                    vanes.move(to: CGPoint(x: x - lean / 2, y: seam + 1))
                    vanes.addLine(to: CGPoint(x: x + lean / 2, y: seam + gap - 1))
                }
                cavity.stroke(vanes, with: .color(Color(white: 0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }

            // The flap. Closed, it's clipped to the casing's rounded bottom so it reads as part
            // of it; open, it's its own rounded blade.
            let top = seam + gap
            let blade = CGRect(x: cap + 0.5, y: top, width: w - 2 * cap - 1, height: face)
            let bladePath = isOn
                ? Path(roundedRect: blade, cornerRadius: min(face / 2, h * 0.08), style: .continuous)
                : Path(blade)
            var flapContext = context
            if !isOn { flapContext.clip(to: casing) }
            flapContext.fill(bladePath, with: .linearGradient(Gradient(colors: [Color(white: 0.97), Color(white: 0.8)]),
                                                              startPoint: CGPoint(x: 0, y: top),
                                                              endPoint: CGPoint(x: 0, y: top + face)))
            if isOn {
                // The leading edge catches the light.
                var edge = Path()
                edge.move(to: CGPoint(x: blade.minX + 3, y: top + 0.6))
                edge.addLine(to: CGPoint(x: blade.maxX - 3, y: top + 0.6))
                flapContext.stroke(edge, with: .color(.white), lineWidth: 1)
            } else {
                // A fine seam between the panel and the closed flap.
                var line = Path()
                line.move(to: CGPoint(x: cap, y: seam))
                line.addLine(to: CGPoint(x: w - cap, y: seam))
                context.stroke(line, with: .color(Color(white: 0.72)), lineWidth: 0.75)
            }

            // Gloss across the top of the front panel, and a crisp outline.
            context.fill(Path(roundedRect: CGRect(x: 2, y: 2, width: w - 4, height: h * 0.45), cornerRadius: radius - 2, style: .continuous),
                         with: .linearGradient(Gradient(colors: [.white.opacity(0.9), .white.opacity(0)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.45)))
            context.stroke(casing, with: .color(Color(white: 0.72).opacity(0.6)), lineWidth: 0.75)
        }
    }
}

/// The set temperature glowing through the casing in the display colour, lit only while the AC runs with its
/// display on.
struct UnitDisplay: View {
    let state: ACState
    let hint: String

    var body: some View {
        let lit = state.isOn && state.display
        GeometryReader { geo in
            let height = geo.size.height
            readout(height: height)
            // On the digits themselves, not the whole width of the unit.
            .hoverHint(hint, edge: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .opacity(lit ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.3), value: lit)
    }

    private func readout(height: Double) -> some View {
        Group {
            if state.mode.usesSetpoint {
                Text(state.setpoint, format: .number.precision(.fractionLength(state.setpoint == state.setpoint.rounded() ? 0 : 1)))
            } else {
                Text("FAN")
            }
        }
        .font(.system(size: height * 0.7, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Color.acDisplay)
        .shadow(color: Color.acDisplay.opacity(0.35), radius: height * 0.1)
        .contentTransition(.numericText(value: state.setpoint))
        .animation(.smooth(duration: 0.45), value: state.setpoint)
    }
}

/// A small steady light on the casing, with a soft glow so it stands out on white.
struct StatusLight: View {
    let color: Color
    let diameter: Double

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.mix(with: .white, by: 0.45), color],
                                 center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: diameter * 0.6))
            .frame(width: diameter, height: diameter)
            .shadow(color: color.opacity(0.7), radius: diameter * 0.4)
    }
}

/// Streams of air particles. Each particle travels out of the outlet in 3D (down, towards the
/// viewer, sideways) and is projected for a viewer slightly above the unit.
struct AirflowCanvas: View {
    let state: ACState
    let angles: LouverAngles
    let time: TimeInterval
    /// Every bit of air on its way out of the unit.
    let air: [AirParticle]

    static let streams = 13
    static let particlesPerStream = 7

    var body: some View {
        Canvas { context, size in
            let tilt = angles.vertical * .pi / 180
            let steer = angles.horizontal * .pi / 180
            let reach = size.height * 1.05
            context.blendMode = .plusLighter
            // Across the outlet: 84% of the unit's width, centred.
            let outlet = ACUnitScene.unitWidth * 0.84
            for particle in air {
                let u = Double(particle.stream) / Double(Self.streams - 1)
                let originX = size.width * (0.5 + (u - 0.5) * outlet)
                let fan = (u - 0.5) * 0.55 // streams spread out a little from the centre
                let progress = particle.progress
                let mode = particle.mode
                let buoyancy = Self.buoyancy(mode)
                let head = Self.point(progress, originX: originX, tilt: tilt, steer: steer + fan,
                                      reach: reach, buoyancy: buoyancy, size: size)
                let tail = Self.point(max(0, progress - 0.12), originX: originX, tilt: tilt, steer: steer + fan,
                                      reach: reach, buoyancy: buoyancy, size: size)
                var path = Path()
                path.move(to: tail.position)
                path.addLine(to: head.position)
                let fade = sin(.pi * progress) * (0.55 + 0.35 * particle.seed) * Self.breath(fan: particle.fan, time: time)
                context.stroke(path,
                               with: .linearGradient(Gradient(colors: [mode.tint.opacity(0), mode.glow.opacity(fade)]),
                                                     startPoint: tail.position, endPoint: head.position),
                               style: StrokeStyle(lineWidth: 1.2 + 2.4 * head.depth, lineCap: .round))
            }
        }
    }

    /// Cool air sinks and warm air rises a little as it travels.
    static func buoyancy(_ mode: ACMode) -> Double {
        switch mode {
        case .cool, .dry: 0.22
        case .heat: -0.18
        default: 0.05
        }
    }

    static func point(_ progress: Double, originX: Double, tilt: Double, steer: Double,
                       reach: Double, buoyancy: Double, size: CGSize) -> (position: CGPoint, depth: Double) {
        let distance = progress * reach
        let forward = cos(tilt) * distance
        let down = sin(tilt) * distance + buoyancy * distance * progress
        let sideways = sin(steer) * distance * 0.9
        let depth = forward / reach // 0 at the unit, ~1 right in front of the viewer
        // Closer air spreads out from the centre, as perspective would have it.
        let x = originX + sideways + (originX - size.width / 2) * depth * 0.35
        let y = 2 + down * 0.85 + forward * 0.32
        return (CGPoint(x: x, y: y), depth)
    }

    /// How far along the air has travelled. Fixed speeds move at a steady pace; Auto moves at
    /// a gentle, medium pace that slowly speeds up and eases off. (MirAIe doesn't report the
    /// speed the AC picks in Auto.) Speed is folded into a phase, never multiplied by the
    /// clock: a changing speed times a large timestamp would make the air jump around.
    static func phase(fan: FanSpeed, time: TimeInterval) -> Double {
        let time = time.truncatingRemainder(dividingBy: 3600)
        switch fan {
        case .auto:
            let pace = 0.36, swell = 0.08, rate = 0.5
            return time * pace + swell / rate * sin(time * rate)
        default:
            return time * pace(fan)
        }
    }

    /// The air as it is when the fan has been steady: evenly spread along each stream, all at
    /// the current speed and mode. Where the animation starts, and all a widget can show.
    static func steadyAir(state: ACState, time: TimeInterval) -> [AirParticle] {
        let phase = phase(fan: state.fan, time: time)
        let speed = speed(fan: state.fan, time: time)
        return (0..<streams).flatMap { stream in
            (0..<particlesPerStream).map { index in
                let seed = noise(stream * 31 + index * 7)
                let progress = (phase + Double(index) / Double(particlesPerStream) + seed)
                    .truncatingRemainder(dividingBy: 1)
                return AirParticle(stream: stream, seed: seed, progress: progress, speed: speed,
                                   fan: state.fan, mode: state.mode)
            }
        }
    }

    /// How fast air leaves the outlet right now: the rate at which `phase(fan:time:)` grows.
    static func speed(fan: FanSpeed, time: TimeInterval) -> Double {
        switch fan {
        case .auto: 0.36 + 0.08 * cos(time.truncatingRemainder(dividingBy: 3600) * 0.5)
        default: pace(fan)
        }
    }

    /// Air travelled per second at each fixed speed: Quiet a slow drift, High more than four
    /// times as fast.
    private static func pace(_ fan: FanSpeed) -> Double {
        switch fan {
        case .quiet: 0.18
        case .low: 0.32
        case .medium: 0.5
        default: 0.8
        }
    }

    /// In Auto the air also brightens and fades a little, so it reads differently from a
    /// fixed speed at a glance.
    static func breath(fan: FanSpeed, time: TimeInterval) -> Double {
        fan == .auto ? 0.75 + 0.25 * sin(time.truncatingRemainder(dividingBy: 3600) * 0.9) : 1
    }

    /// Stable pseudo-random value in 0..<1, so particles don't march in lockstep.
    static func noise(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898) * 43758.5453
        return value - value.rounded(.down)
    }
}

#Preview("AC unit") {
    var state = ACState()
    state.isOn = true
    state.verticalLouver = 0
    state.horizontalLouver = 0
    return ACUnitView(state: state)
        .frame(width: 340, height: 190)
        .padding()
        .background(.black)
}
