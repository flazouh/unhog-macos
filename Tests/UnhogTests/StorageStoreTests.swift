import Foundation
import Testing
import UnhogCore
@testable import Unhog

@Suite("Storage store lifecycle")
struct StorageStoreTests {
    @Test("Scan completes while the store remains alive")
    @MainActor
    func scanCompletesWhileStoreRemainsAlive() async throws {
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

        let store = StorageStore()
        store.scan(
            locations: [
                StorageLocation(id: "first", name: "First", url: first),
                StorageLocation(id: "second", name: "Second", url: second),
            ]
        )

        try await waitForScanCompletion(on: store, timeout: .seconds(5))

        #expect(store.scanState == .complete)
        #expect(store.folders.map(\.id) == ["second", "first"])
    }

    @Test("Scan survives after a view-scoped reference goes away")
    @MainActor
    func scanSurvivesAfterViewScopedReferenceEnds() async throws {
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

        let hoistedStore = StorageStore()
        do {
            let viewScopedStore = hoistedStore
            viewScopedStore.scan(
                locations: [
                    StorageLocation(id: "first", name: "First", url: first),
                    StorageLocation(id: "second", name: "Second", url: second),
                ]
            )
        }

        try await waitForScanCompletion(on: hoistedStore, timeout: .seconds(5))

        #expect(hoistedStore.scanState == .complete)
        #expect(hoistedStore.folders.count == 2)
    }

    @Test("Deallocation cancels an in-flight storage scan")
    @MainActor
    func deallocationCancelsInFlightScan() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let locations = try (0..<8).map { index in
            let folder = root.appending(
                path: "Folder-\(index)",
                directoryHint: .isDirectory
            )
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            for fileIndex in 0..<64 {
                try Data(repeating: UInt8(index), count: 512).write(
                    to: folder.appending(path: "file-\(fileIndex).bin")
                )
            }
            return StorageLocation(
                id: "folder-\(index)",
                name: "Folder \(index)",
                url: folder
            )
        }

        var optionalStore: StorageStore? = StorageStore()
        weak var weakStore = optionalStore
        optionalStore?.scan(locations: locations)
        try await waitUntilScanning(optionalStore, timeout: .seconds(2))
        optionalStore = nil

        try await Task.sleep(for: .milliseconds(250))
        #expect(weakStore == nil)
    }

    @MainActor
    private func waitForScanCompletion(
        on store: StorageStore,
        timeout: Duration
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while store.scanState == .scanning {
            try await Task.sleep(for: .milliseconds(20))
            if ContinuousClock.now >= deadline {
                Issue.record("Timed out waiting for storage scan to finish.")
                return
            }
        }
    }

    @MainActor
    private func waitUntilScanning(
        _ store: StorageStore?,
        timeout: Duration
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while store?.scanState != .scanning {
            try await Task.sleep(for: .milliseconds(20))
            if ContinuousClock.now >= deadline {
                Issue.record("Timed out waiting for storage scan to start.")
                return
            }
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(
                path: "unhog-storage-store-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}
