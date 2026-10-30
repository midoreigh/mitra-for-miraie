import SwiftUI
import MitraKit

/// The menu bar panel: sign-in until there's an account, then the controls.
struct PanelView: View {
    @Environment(ACStore.self) private var store

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
    }
}
