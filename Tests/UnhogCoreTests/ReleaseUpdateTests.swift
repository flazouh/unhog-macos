import Foundation
import Testing
@testable import UnhogCore

@Suite("Release updates")
struct ReleaseUpdateTests {
    @Test("App versions compare in semver order")
    func comparesVersions() {
        let current = AppVersion(major: 0, minor: 1, patch: 1)
        let newer = AppVersion(major: 0, minor: 1, patch: 2)
        let older = AppVersion(major: 0, minor: 1, patch: 0)

        #expect(current < newer)
        #expect(older < current)
        #expect(AppVersion(parsing: "v0.1.2") == newer)
    }

    @Test("GitHub release payloads parse into comparable updates")
    func parsesGitHubReleasePayload() throws {
        let data = Data(
            """
            {
              "tag_name": "v0.1.2",
              "name": "Unhog 0.1.2",
              "body": "Adds automatic updates.",
              "html_url": "https://github.com/flazouh/unhog/releases/tag/v0.1.2",
              "assets": [
                {
                  "name": "Unhog-0.1.2.dmg",
                  "browser_download_url": "https://example.com/Unhog-0.1.2.dmg"
                }
              ]
            }
            """.utf8
        )

        let release = try GitHubReleaseParser.parse(data)
        let comparison = try ReleaseUpdateChecker().compare(
            currentVersion: AppVersion(major: 0, minor: 1, patch: 1),
            release: release
        )

        guard case let .updateAvailable(update) = comparison else {
            Issue.record("Expected an available update.")
            return
        }

        #expect(update.version.displayString == "0.1.2")
        #expect(update.title == "Unhog 0.1.2")
        #expect(update.releaseNotes == "Adds automatic updates.")
        #expect(
            update.downloadURL.absoluteString
                == "https://example.com/Unhog-0.1.2.dmg"
        )
    }

    @Test("Matching versions report up to date")
    func reportsUpToDate() throws {
        let release = GitHubReleasePayload(
            tagName: "v0.1.2",
            title: "Unhog 0.1.2",
            body: "No changes",
            pageURL: URL(string: "https://example.com/release")!,
            assets: [
                GitHubReleaseAsset(
                    name: "Unhog-0.1.2.dmg",
                    downloadURL: URL(string: "https://example.com/Unhog-0.1.2.dmg")!
                )
            ]
        )

        let comparison = try ReleaseUpdateChecker().compare(
            currentVersion: AppVersion(major: 0, minor: 1, patch: 2),
            release: release
        )

        #expect(comparison == .upToDate)
    }
}
