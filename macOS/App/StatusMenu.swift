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
        if let store, store.isDemo {
            menu.addItem(withTitle: "Previewing a demo AC", action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(.separator())
            menu.addItem(item("Preview Update Banner", #selector(previewUpdate)))
            menu.addItem(item("Exit Demo", #selector(togglePreview)))
        } else if let store, store.phase == .ready {
            var status = store.isLive ? "Connected" : "Connecting…"
            if let signal = store.state.wifiSignal { status += " · AC Wi-Fi \(signal) dBm" }
            menu.addItem(withTitle: status, action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(.separator())
            menu.addItem(item("Refresh", #selector(refresh)))
            let preview = item("Preview Mode (Don't Send Commands)", #selector(togglePreview))
            preview.state = store.isPreviewing ? .on : .off
            menu.addItem(preview)
            if store.isPreviewing { menu.addItem(item("Preview Update Banner", #selector(previewUpdate))) }
        }
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        if let release = UpdateChecker.shared.release {
            menu.addItem(item("Update to \(release.version)…", #selector(update)))
        } else {
            menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        }
        menu.addItem(.separator())
        if store?.phase == .ready, store?.isDemo == false {
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

    @objc func showSettings() {
        NSApp.activate()
        openSettings?()
    }

    @objc private func togglePreview() { store?.isPreviewing.toggle() }

    @objc private func previewUpdate() { UpdateChecker.shared.simulate() }

    @objc private func update() { Task { await UpdateChecker.shared.update() } }

    /// Checks now and says what it found: an update shows in the panel, anything else in an alert.
    @objc private func checkForUpdates() {
        Task {
            let updates = UpdateChecker.shared
            await updates.check()
            let alert = NSAlert()
            switch updates.state {
            case .available(let release):
                alert.messageText = "Version \(release.version) is available"
                alert.informativeText = "You have \(updates.currentVersion)."
                alert.addButton(withTitle: "Update")
                alert.addButton(withTitle: "Later")
            case .failed(let message):
                alert.messageText = "Couldn't check for updates"
                alert.informativeText = message
            default:
                alert.messageText = "You're up to date"
                alert.informativeText = "Mitra for MirAIe \(updates.currentVersion) is the latest version."
            }
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn, updates.release != nil {
                await updates.update()
            }
        }
    }

    @objc private func signOut() { store?.signOut() }

    @objc private func quit() { NSApp.terminate(nil) }
}
