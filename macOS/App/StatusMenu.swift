import AppKit
import MitraKit

/// The menu shown when right-clicking the menu bar icon, for the less frequent actions.
/// MenuBarExtra has no API for this, so it watches for right clicks on the app's own status
/// bar button.
@MainActor
final class StatusMenu: NSObject {
    static let shared = StatusMenu()

    private weak var store: ACStore?
    private var openSettings: (() -> Void)?
    private var monitor: Any?

    func install(store: ACStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.openSettings = openSettings
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, let window = event.window, window.className.contains("StatusBarWindow"),
                  let view = window.contentView else { return event }
            NSMenu.popUpContextMenu(menu(), with: event, for: view)
            return nil
        }
    }

    private func menu() -> NSMenu {
        let menu = NSMenu()
        if let store, store.phase == .ready {
            var status = store.isLive ? "Connected" : "Connecting…"
            if let signal = store.state.wifiSignal { status += " · AC Wi-Fi \(signal) dBm" }
            menu.addItem(withTitle: status, action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(.separator())
            menu.addItem(item("Refresh", #selector(refresh)))
            let preview = item("Preview Mode (Don't Send Commands)", #selector(togglePreview))
            preview.state = store.isPreviewing ? .on : .off
            menu.addItem(preview)
        }
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        if store?.phase == .ready {
            menu.addItem(item("Sign Out", #selector(signOut)))
        }
        menu.addItem(item("Quit Mitra for MirAIe", #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refresh() { Task { await store?.start() } }

    @objc private func showSettings() {
        NSApp.activate()
        openSettings?()
    }

    @objc private func togglePreview() { store?.isPreviewing.toggle() }

    @objc private func signOut() { store?.signOut() }

    @objc private func quit() { NSApp.terminate(nil) }
}
