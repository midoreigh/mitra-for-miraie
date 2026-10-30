import AppKit
import Observation

/// Looks for newer releases on GitHub and fetches the installer. Downloaded copies of the app
/// can't replace themselves (they're sandboxed and not signed with an Apple Developer ID), so
/// an update ends with the installer open and the user dragging the app into Applications.
@MainActor @Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    struct Release: Equatable {
        let version: String
        let page: URL
        /// The DMG, if the release has one.
        let installer: URL?
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Release)
        /// The installer is open; the user drags the app into Applications and reopens it.
        case installerOpen(Release)
        case failed(String)
    }

    private(set) var state = State.idle
    private(set) var lastChecked: Date? = UserDefaults.standard.object(forKey: Key.lastChecked) as? Date

    var checksAutomatically = UserDefaults.standard.object(forKey: Key.automatic) as? Bool ?? true {
        didSet { UserDefaults.standard.set(checksAutomatically, forKey: Key.automatic) }
    }

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    /// The newer release, while there's one to offer.
    var release: Release? {
        switch state {
        case .available(let release), .downloading(let release), .installerOpen(let release): release
        default: nil
        }
    }

    private enum Key {
        static let lastChecked = "updates.lastChecked"
        static let automatic = "updates.automatic"
    }

    private static let latest = URL(string: "https://api.github.com/repos/midoreigh/mitra-for-miraie/releases/latest")!
    private var schedule: Task<Void, Never>?

    /// Checks shortly after launch, then about once a day, while automatic checks are on.
    func start() {
        guard schedule == nil else { return }
        schedule = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            while !Task.isCancelled {
                if let self, self.checksAutomatically,
                   (self.lastChecked.map { -$0.timeIntervalSinceNow > 24 * 3600 } ?? true) {
                    await self.check()
                }
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    func check() async {
        if case .downloading = state { return }
        state = .checking
        do {
            var request = URLRequest(url: Self.latest, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Mitra-for-MirAIe/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else {
                throw URLError(.badServerResponse)
            }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let installer = (json["assets"] as? [[String: Any]] ?? [])
                .first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
                .flatMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
            lastChecked = Date()
            UserDefaults.standard.set(lastChecked, forKey: Key.lastChecked)
            state = Self.isVersion(version, newerThan: currentVersion)
                ? .available(Release(version: version, page: page, installer: installer))
                : .upToDate
        } catch {
            state = .failed("Couldn't check for updates. Check your internet connection.")
        }
    }

    /// Downloads the installer to Downloads and opens it. Without one, opens the release page.
    func update() async {
        guard let release else { return }
        guard let installer = release.installer else {
            NSWorkspace.shared.open(release.page)
            return
        }
        state = .downloading(release)
        do {
            let (file, response) = try await URLSession.shared.download(from: installer)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let downloads = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
            let destination = downloads.appendingPathComponent(installer.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: file, to: destination)
            NSWorkspace.shared.open(destination)
            state = .installerOpen(release)
        } catch {
            state = .available(release)
            NSWorkspace.shared.open(release.page) // fall back to downloading it in the browser
        }
    }

    /// "1.10.0" is newer than "1.9.2"; missing parts count as 0.
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}
