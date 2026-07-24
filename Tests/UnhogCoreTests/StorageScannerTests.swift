import Foundation
import Testing
@testable import UnhogCore

@Suite("Storage scanning")
struct StorageScannerTests {
    @Test("Volume capacity is internally consistent")
    func readsVolumeCapacity() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let snapshot = try StorageScanner().volumeSnapshot(for: root)

        #expect(snapshot.totalBytes > 0)
        #expect(snapshot.availableBytes <= snapshot.totalBytes)
        #expect(
            snapshot.usedBytes
                == snapshot.totalBytes - snapshot.availableBytes
        )
    }

    @Test("Folder results are ranked by size")
    func ranksFoldersBySize() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let small = root.appending(path: "Small")
        let large = root.appending(path: "Large")
        try FileManager.default.createDirectory(
            at: small,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: large,
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: 128).write(
            to: small.appending(path: "small.bin")
        )
        try Data(repeating: 2, count: 4_096).write(
            to: large.appending(path: "large.bin")
        )

        let results = try StorageScanner().scan(
            [
                StorageLocation(id: "small", name: "Small", url: small),
                StorageLocation(id: "large", name: "Large", url: large),
            ]
        )

        #expect(results.map(\.id) == ["large", "small"])
        #expect(results.map(\.bytes) == [4_096, 128])
        #expect(results.map(\.fileCount) == [1, 1])
        #expect(results.allSatisfy { $0.status == .available })
    }

    @Test("Progress snapshots expose discoveries before completion")
    func reportsProgressiveDiscoveries() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appending(path: "First")
        let second = root.appending(path: "Second")
        try FileManager.default.createDirectory(
            at: first,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: second,
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: 128).write(
            to: first.appending(path: "one.bin")
        )
        try Data(repeating: 2, count: 256).write(
            to: second.appending(path: "two.bin")
        )

        var snapshots: [StorageScanProgress] = []
        let results = try StorageScanner().scan(
            [
                StorageLocation(id: "first", name: "First", url: first),
                StorageLocation(id: "second", name: "Second", url: second),
            ],
            onProgress: { snapshots.append($0) }
        )

        #expect(
            snapshots.contains {
                $0.completedLocationCount < $0.totalLocationCount
                    && $0.discoveredFileCount > 0
                    && !$0.folders.isEmpty
            }
        )
        let final = try #require(snapshots.last)
        #expect(final.completedLocationCount == 2)
        #expect(final.totalLocationCount == 2)
        #expect(final.activeLocationID == nil)
        #expect(final.discoveredFileCount == 2)
        #expect(final.folders == results)
    }

    @Test("Symbolic links do not count external files")
    func skipsSymbolicLinks() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let scanned = root.appending(path: "Scanned")
        let external = root.appending(path: "External")
        try FileManager.default.createDirectory(
            at: scanned,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: external,
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: 64).write(
            to: scanned.appending(path: "local.bin")
        )
        try Data(repeating: 2, count: 8_192).write(
            to: external.appending(path: "external.bin")
        )
        try FileManager.default.createSymbolicLink(
            at: scanned.appending(path: "external-link"),
            withDestinationURL: external
        )

        let result = try #require(
            StorageScanner().scan(
                [
                    StorageLocation(
                        id: "scanned",
                        name: "Scanned",
                        url: scanned
                    )
                ]
            ).first
        )

        #expect(result.bytes == 64)
        #expect(result.fileCount == 1)
    }

    @Test("Unreadable or missing folders remain visible")
    func reportsUnavailableFolders() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appending(path: "Missing")

        let result = try #require(
            StorageScanner().scan(
                [
                    StorageLocation(
                        id: "missing",
                        name: "Missing",
                        url: missing
                    )
                ]
            ).first
        )

        #expect(result.status == .unavailable)
        #expect(result.bytes == 0)
        #expect(result.fileCount == 0)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(
                path: "unhog-storage-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}
