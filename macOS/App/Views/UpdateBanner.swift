import SwiftUI
import MitraKit
import MitraUI

/// A quiet strip at the bottom of the panel while there's a newer version to install.
struct UpdateBanner: View {
    let updates: UpdateChecker

    var body: some View {
        if let release = updates.release {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title(release)).font(.callout.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                action
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func title(_ release: UpdateChecker.Release) -> String {
        switch updates.state {
        case .downloading: "Downloading \(release.version)…"
        case .installerOpen: "Version \(release.version) is ready"
        default: "Version \(release.version) is available"
        }
    }

    private var detail: String {
        switch updates.state {
        case .installerOpen: "Quit, drag the app into Applications to replace it, then open it again."
        default: "You have \(updates.currentVersion)."
        }
    }

    @ViewBuilder
    private var action: some View {
        switch updates.state {
        case .downloading:
            ProgressView().controlSize(.small)
        case .installerOpen:
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.glass)
        default:
            Button("Update") { Task { await updates.update() } }
                .buttonStyle(.glassProminent)
        }
    }
}
