import Foundation
import Observation
import os

/// A release on GitHub, as `releases/latest` returns it.
struct AppRelease: Decodable, Equatable, Identifiable {
    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [Asset]
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, assets
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }

    var id: String { tagName }

    /// "v1.1" → "1.1".
    var version: String {
        tagName.hasPrefix("v") || tagName.hasPrefix("V") ? String(tagName.dropFirst()) : tagName
    }

    var publishedDate: Date? {
        publishedAt.flatMap { try? Date($0, strategy: .iso8601) }
    }

    /// The disk image to download, else the zip, else the release page.
    var downloadURL: URL {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }?.browserDownloadURL
            ?? assets.first { $0.name.lowercased().hasSuffix(".zip") }?.browserDownloadURL
            ?? htmlURL
    }
}

/// Looks for new releases of mrgsdev/Toolbelt on GitHub and offers to download them.
///
/// Unlike an auto-updater it never replaces the app by itself: Toolbelt is signed ad hoc, so there is
/// no developer signature to check a downloaded build against.
@MainActor
@Observable
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case failed(String)
    }

    static let shared = Updater()

    private(set) var state: State = .idle

    static let releasesPage = URL(string: "https://github.com/mrgsdev/Toolbelt/releases")!
    private static let latestRelease = URL(string: "https://api.github.com/repos/mrgsdev/Toolbelt/releases/latest")!
    private static let skippedKey = "skippedUpdateVersion"
    private static let log = Logger(subsystem: "dev.mrgs.Toolbelt", category: "update")

    /// The version the user chose to skip: offered again only from «Проверить обновления…».
    var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: Self.skippedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.skippedKey) }
    }

    @ObservationIgnored private var lastCheck = Date.distantPast
    /// Put off with «Позже»; not offered again until the next launch.
    @ObservationIgnored private var postponed: String?

    private let session = URLSession(configuration: .ephemeral)

    private init() {}

    /// Checks at most twice a day without asking; returns true when there is an update to offer.
    func checkInBackground() async -> Bool {
        guard Date().timeIntervalSince(lastCheck) > 12 * 3600, state != .checking else { return false }
        await check()
        if case .available(let release) = state, release.version != postponed, release.version != skippedVersion {
            return true
        }
        if case .available = state {} else { state = .idle }
        return false
    }

    /// «Проверить обновления…»: the window shows the result, including "no updates" and errors.
    func checkNow() async {
        guard state != .checking else { return }
        await check()
    }

    func skip(_ release: AppRelease) {
        skippedVersion = release.version
    }

    /// The window closed: an offered version counts as «Позже».
    func windowClosed() {
        if case .available(let release) = state { postponed = release.version }
        state = .idle
    }

    private func check() async {
        state = .checking
        lastCheck = Date()
        do {
            var request = URLRequest(url: Self.latestRelease)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            // No release published yet.
            if status == 404 {
                state = .upToDate
                return
            }
            guard (200..<300).contains(status) else {
                state = .failed("GitHub ответил ошибкой \(status).")
                return
            }
            let release = try JSONDecoder().decode(AppRelease.self, from: data)
            state = Self.isVersion(release.version, newerThan: AppInfo.version) ? .available(release) : .upToDate
        } catch {
            Self.log.error("update check failed: \(error.localizedDescription, privacy: .public)")
            state = .failed("Не удалось проверить обновления: \(error.localizedDescription)")
        }
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let parse = { (version: String) in version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 } }
        let lhs = parse(candidate), rhs = parse(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
