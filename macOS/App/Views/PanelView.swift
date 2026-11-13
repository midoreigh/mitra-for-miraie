import SwiftUI
import MitraKit

/// The menu bar panel: sign-in until there's an account, then the controls.
struct PanelView: View {
    @Environment(ACStore.self) private var store
    /// The panel's window stays alive while closed; without this the animations keep running.
    @State private var isOnScreen = true

    var body: some View {
        Group {
            switch store.phase {
            case .signedOut, .failed:
                SignInView()
            case .loading where store.devices.isEmpty:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Finding your air conditioners…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            case .loading, .ready:
                ControlView()
            }
        }
        .frame(width: 368)
        .environment(\.isOffScreen, !isOnScreen)
        .background(WindowVisibilityReader { isOnScreen = $0 })
    }
}

/// Reports whether the window holding it can be seen: closed, it's ordered out; open but
/// covered, it's occluded. Either way it isn't visible.
private struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onChange = onChange
    }

    final class TrackingView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            report()
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) ?? false
            // Not during a SwiftUI update.
            DispatchQueue.main.async { [weak self] in self?.onChange?(visible) }
        }
    }
}
