import AppKit
import Combine
import Foundation
import UnhogCore

@MainActor
final class UpdateController: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(ReleaseUpdate)
        case failed(String)
        case downloading
        case readyToInstall(URL)
    }

    @Published private(set) var state: State = .idle

    private let repository: String
    private let session: URLSession
    private let checker: ReleaseUpdateChecker
    private let defaults: UserDefaults
    private let lastAutomaticCheckKey = "unhog.lastAutomaticUpdateCheck"

    init(
        repository: String = "flazouh/unhog",
        session: URLSession = .shared,
        checker: ReleaseUpdateChecker = ReleaseUpdateChecker(),
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.session = session
        self.checker = checker
        self.defaults = defaults
    }

    var currentVersionLabel: String {
        currentVersion?.displayString ?? "Unknown"
    }

    func checkForUpdates(
        showUpToDateAlert: Bool = true,
        showUpdateAlert: Bool = true
    ) async {
        state = .checking
        do {
            let comparison = try await fetchComparison()
            apply(
                comparison,
                showUpToDateAlert: showUpToDateAlert,
                showUpdateAlert: showUpdateAlert
            )
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func checkForUpdatesIfNeeded(
        automaticallyCheck: Bool,
        minimumInterval: TimeInterval = 86_400
    ) async {
        guard automaticallyCheck else { return }
        guard shouldPerformAutomaticCheck(minimumInterval: minimumInterval) else {
            return
        }

        defaults.set(Date(), forKey: lastAutomaticCheckKey)
        await checkForUpdates(
            showUpToDateAlert: false,
            showUpdateAlert: true
        )
    }

    func downloadUpdate() async {
        guard case let .updateAvailable(update) = state else { return }
        state = .downloading

        do {
            let destination = try await downloadAsset(
                from: update.downloadURL,
                suggestedName: "Unhog-\(update.version.displayString).dmg"
            )
            state = .readyToInstall(destination)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func openDownloadedUpdate() {
        guard case let .readyToInstall(url) = state else { return }
        NSWorkspace.shared.open(url)
    }

    func openReleasePage() {
        guard case let .updateAvailable(update) = state else { return }
        NSWorkspace.shared.open(update.pageURL)
    }

    private var currentVersion: AppVersion? {
        guard
            let rawVersion = Bundle.main.infoDictionary?[
                "CFBundleShortVersionString"
            ] as? String
        else {
            return nil
        }
        return AppVersion(parsing: rawVersion)
    }

    private func shouldPerformAutomaticCheck(
        minimumInterval: TimeInterval
    ) -> Bool {
        guard
            let lastCheck = defaults.object(
                forKey: lastAutomaticCheckKey
            ) as? Date
        else {
            return true
        }
        return Date().timeIntervalSince(lastCheck) >= minimumInterval
    }

    private func fetchComparison() async throws -> ReleaseUpdateComparison {
        guard let currentVersion else {
            throw ReleaseUpdateError.invalidVersion
        }

        var request = URLRequest(
            url: URL(
                string: "https://api.github.com/repos/\(repository)/releases/latest"
            )!
        )
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "Unhog/\(currentVersion.displayString)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw ReleaseUpdateError.invalidResponse
        }

        let release = try GitHubReleaseParser.parse(data)
        return try checker.compare(
            currentVersion: currentVersion,
            release: release
        )
    }

    private func apply(
        _ comparison: ReleaseUpdateComparison,
        showUpToDateAlert: Bool,
        showUpdateAlert: Bool
    ) {
        switch comparison {
        case .upToDate:
            state = .upToDate
            if showUpToDateAlert {
                presentAlert(
                    title: "You're up to date",
                    message: "Unhog \(currentVersionLabel) is the latest release."
                )
            }
        case let .updateAvailable(update):
            state = .updateAvailable(update)
            if showUpdateAlert {
                presentUpdateAlert(update)
            }
        }
    }

    private func downloadAsset(
        from url: URL,
        suggestedName: String
    ) async throws -> URL {
        let (temporaryURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw ReleaseUpdateError.invalidResponse
        }

        let downloads = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first!
        let destination = downloads.appending(path: suggestedName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func presentUpdateAlert(_ update: ReleaseUpdate) {
        let alert = NSAlert()
        alert.messageText = "Update available"
        alert.informativeText =
            "Unhog \(update.version.displayString) is ready to download."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Release notes")
        alert.addButton(withTitle: "Not now")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task { await downloadUpdate() }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(update.pageURL)
        default:
            break
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
