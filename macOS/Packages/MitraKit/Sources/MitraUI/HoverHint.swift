import AppKit
import SwiftUI

/// When the user last clicked anywhere in the app, so hints can stay out of the way of
/// clicking: a click hides the hint it would otherwise show, and so does arriving over a
/// control because a click moved things under the pointer.
@MainActor @Observable
final class HintCenter {
    static let shared = HintCenter()

    private(set) var lastClick = Date.distantPast
    @ObservationIgnored private var monitor: Any?

    func startWatchingClicks() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            MainActor.assumeIsolated { HintCenter.shared.lastClick = Date() }
            return event
        }
    }

    /// Whether a hint for a hover that began at `start` may show: no click since then, and
    /// none just before it either.
    func allowsHint(hoverStartedAt start: Date) -> Bool {
        lastClick.addingTimeInterval(0.6) < start
    }
}

/// A small glass label beside a control while the pointer rests on it. macOS's own tooltips
/// (`.help`) take a long time to appear in a menu bar panel, and often don't appear at all
/// while another app is active.
struct HoverHint: ViewModifier {
    let text: String
    let edge: Edge
    /// For hints above or below: which edge of the control they line up with. Centred by
    /// default; leading or trailing keeps a hint near the panel's edge from being cut off.
    var anchor: HorizontalAlignment = .center
    var isShown: Bool?
    var onHover: ((Bool) -> Void)?
    @State private var hovering = false
    @State private var shown = false
    @State private var delay: Task<Void, Never>?
    @State private var labelSize = CGSize.zero
    @State private var hoverStart = Date.distantPast

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                if inside {
                    hoverStart = Date()
                    HintCenter.shared.startWatchingClicks()
                }
                onHover?(inside)
                delay?.cancel()
                if inside {
                    delay = Task {
                        try? await Task.sleep(for: .seconds(0.8))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.15)) { shown = true }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.1)) { shown = false }
                }
            }
            .overlay(alignment: alignment) {
                if shown, hovering, isShown ?? true, HintCenter.shared.allowsHint(hoverStartedAt: hoverStart) {
                    label.transition(.opacity.combined(with: .scale(0.9)))
                }
            }
            .zIndex(shown ? 1 : 0)
            .accessibilityHint(text)
    }

    /// Measured, then moved fully outside the control on the chosen side, so it never covers it.
    private var label: some View {
        let gap: CGFloat = 6
        let offset: CGSize = switch edge {
        case .top: CGSize(width: 0, height: -(labelSize.height + gap))
        case .bottom: CGSize(width: 0, height: labelSize.height + gap)
        case .leading: CGSize(width: -(labelSize.width + gap), height: 0)
        case .trailing: CGSize(width: labelSize.width + gap, height: 0)
        }
        return Text(text)
            .font(.caption.weight(.medium))
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { labelSize = $0 }
            .opacity(labelSize == .zero ? 0 : 1)
            .offset(offset)
            .allowsHitTesting(false)
    }

    private var alignment: Alignment {
        switch edge {
        case .top: Alignment(horizontal: anchor, vertical: .top)
        case .bottom: Alignment(horizontal: anchor, vertical: .bottom)
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}

public extension View {
    /// Names a control in a glass label on one side of it, shortly after the pointer rests on it.
    func hoverHint(_ text: String, edge: Edge = .top, anchor: HorizontalAlignment = .center,
                   isShown: Bool? = nil, onHover: ((Bool) -> Void)? = nil) -> some View {
        modifier(HoverHint(text: text, edge: edge, anchor: anchor, isShown: isShown, onHover: onHover))
    }
}
