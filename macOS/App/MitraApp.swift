import AppKit
import SwiftUI
import MitraKit

@main
struct MitraApp: App {
    @State private var store = ACStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}

/// The AC icon, plus the setpoint while the selected AC is running.
/// Also sets up the right-click menu, since the label is always on screen.
struct MenuBarLabel: View {
    let store: ACStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let state = store.state
        let isRunning = store.phase == .ready && state.isOn
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(filled: isRunning))
            if isRunning { Text(ACState.format(state.setpoint)) }
        }
        .onAppear {
            StatusMenu.shared.install(store: store) { openSettings() }
        }
    }
}

/// A plain indoor unit drawn to sit with other menu bar icons: no airflow lines, just the
/// casing and its outlet slot. Solid while the AC runs, an outline while it's off.
enum MenuBarIcon {
    static func image(filled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: true) { _ in
            let body = NSBezierPath(roundedRect: NSRect(x: 1, y: 4, width: 20, height: 8.5), xRadius: 2.4, yRadius: 2.4)
            let slot = NSBezierPath(roundedRect: NSRect(x: 4, y: 9.4, width: 14, height: 1.3), xRadius: 0.65, yRadius: 0.65)
            let light = NSBezierPath(ovalIn: NSRect(x: 16, y: 6.1, width: 1.7, height: 1.7))
            NSColor.black.set()
            if filled {
                body.fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                slot.fill()
                light.fill()
            } else {
                body.lineWidth = 1.3
                body.stroke()
                slot.fill()
                light.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
