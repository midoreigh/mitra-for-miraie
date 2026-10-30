import SwiftUI
import MitraKit
import MitraUI

/// A row of choices in one glass capsule; a tinted pill slides to the chosen one.
struct GlassSegments<Value: Hashable, Label: View>: View {
    let values: [Value]
    let selection: Value
    let tint: Color
    let select: (Value) -> Void
    /// What each option is, shown on hover.
    var hint: (Value) -> String
    /// Fill the chosen option with the tint. Off, it's solid white with dark text instead, like
    /// the power button: just as clear, without adding more colour to the panel.
    var prominent = true
    @ViewBuilder let label: (Value, Bool) -> Label
    @Namespace private var namespace
    @State private var hovered: Value?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Button { select(value) } label: {
                    // Equal widths, so choosing an option only slides the pill; nothing resizes.
                    label(value, isSelected)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(isSelected ? (prominent ? Color.white : Color.black) : .secondary)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(prominent ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.white.opacity(0.92)))
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .hoverHint(hint(value), isShown: hovered == value) { inside in
                    if inside { hovered = value } else if hovered == value { hovered = nil }
                }
                .zIndex(hovered == value ? 1 : 0)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy, value: selection)
    }
}

/// A bar with its name and current value on the left, e.g. "Fan / Auto".
struct LabeledBar<Bar: View>: View {
    let title: String
    let value: String
    @ViewBuilder let bar: Bar

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Swaps at once: a crossfade showed both names for a moment.
                Text(value)
                    .font(.callout.weight(.semibold))
                    .transaction { $0.animation = nil }
            }
            .lineLimit(1)
            .frame(width: 58, alignment: .leading)
            bar
        }
    }
}

/// A round glass button with a symbol.
struct RoundButton: View {
    let symbol: String
    var size: CGFloat = 34
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(tint == nil ? Color.primary : .white)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(), in: .circle)
    }
}

/// One louver position drawn as a vane: up/down tilts from level to pointing down,
/// left/right leans from far left to far right. Swing shows a double arrow instead.
struct LouverGlyph: View {
    enum Axis { case vertical, horizontal }

    let axis: Axis
    let position: Int

    var body: some View {
        if position == Louver.swing {
            Image(systemName: axis == .vertical ? "arrow.up.and.down" : "arrow.left.and.right")
                .font(.system(size: 11, weight: .bold))
        } else {
            Canvas { context, size in
                let length = min(size.width, size.height) * 0.8
                var vane = Path()
                switch axis {
                case .vertical:
                    let angle = LouverAngles.vertical(position) * .pi / 180
                    let pivot = CGPoint(x: (size.width - length * cos(angle)) / 2, y: (size.height - length * sin(angle)) / 2)
                    vane.move(to: pivot)
                    vane.addLine(to: CGPoint(x: pivot.x + length * cos(angle), y: pivot.y + length * sin(angle)))
                    context.fill(Path(ellipseIn: CGRect(x: pivot.x - 1.8, y: pivot.y - 1.8, width: 3.6, height: 3.6)),
                                 with: .foreground)
                case .horizontal:
                    let angle = LouverAngles.horizontal(position) * .pi / 180
                    let top = CGPoint(x: size.width / 2 - length / 2 * sin(angle), y: (size.height - length) / 2)
                    vane.move(to: top)
                    vane.addLine(to: CGPoint(x: top.x + length * sin(angle), y: top.y + length * cos(angle)))
                }
                context.stroke(vane, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .frame(width: 14, height: 14)
        }
    }
}


/// The backdrop of the panel's top: a slowly drifting graphite mesh with rounded bottom
/// corners, dimmer while the AC is off. Shared by the controls and the sign-in screen.
struct HeroBackground: View {
    let isOn: Bool

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous)
        let colors = HeroPalette(isOn: isOn).colors
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !isOn)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [Float(0.5 + 0.12 * sin(t * 0.21)), Float(0.42 + 0.1 * cos(t * 0.17))], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: colors)
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(.white.opacity(0.08)) }
        .animation(.easeInOut(duration: 0.8), value: isOn)
    }
}

/// The hero's background colours: a cool graphite night sky, lighter where the air comes
/// out and fading to near black at the bottom, where the controls sit. The same in every
/// mode; the air itself carries the mode's colour. Dimmer while the AC is off.
private struct HeroPalette {
    let isOn: Bool

    var colors: [Color] {
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
