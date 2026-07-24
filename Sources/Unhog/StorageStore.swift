import Combine
import Foundation
import UnhogCore

@MainActor
final class StorageStore: ObservableObject {
    enum ScanState: Equatable {
        case idle
        case scanning
        case complete
        case failed(String)
    }

    @Published private(set) var volume: StorageVolumeSnapshot?
    @Published private(set) var folders: [StorageFolderUsage] = []
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var scanProgress: StorageScanProgress?

    private let scanner: StorageScanner
    private var overviewTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var scanWorker: Task<StorageFolderLoadOutcome, Never>?
    private var scanContinuation:
        AsyncStream<StorageScanProgress>.Continuation?

    init(scanner: StorageScanner = StorageScanner()) {
        self.scanner = scanner
    }

    func prepare() {
        guard volume == nil, overviewTask == nil else { return }
        let scanner = scanner
        overviewTask = Task { [weak self] in
            let outcome = await Task.detached(priority: .utility) {
                StorageVolumeLoadOutcome {
                    try scanner.volumeSnapshot()
                }
            }.value
            guard !Task.isCancelled else { return }
            self?.overviewTask = nil
            switch outcome {
            case let .loaded(snapshot):
                self?.volume = snapshot
            case let .failed(message):
                self?.scanState = .failed(message)
            }
        }
    }

    func scan() {
        guard scanState != .scanning else { return }
        scanTask?.cancel()
        scanState = .scanning
        folders = []
        scanProgress = nil

        let scanner = scanner
        let locations = StorageLocation.commonLocations()
        let stream = AsyncStream.makeStream(
            of: StorageScanProgress.self,
            bufferingPolicy: .bufferingNewest(2)
        )
        scanContinuation = stream.continuation
        let worker = Task.detached(priority: .utility) {
            defer { stream.continuation.finish() }
            return StorageFolderLoadOutcome {
                try scanner.scan(locations) { progress in
                    stream.continuation.yield(progress)
                }
            }
        }
        scanWorker = worker
        scanTask = Task { [weak self] in
            for await progress in stream.stream {
                guard !Task.isCancelled else { return }
                self?.scanProgress = progress
                self?.folders = progress.folders
            }

            let outcome = await worker.value
            guard !Task.isCancelled else { return }
            self?.scanTask = nil
            self?.scanWorker = nil
            self?.scanContinuation = nil
            switch outcome {
            case let .loaded(folders):
                self?.folders = folders
                self?.scanState = .complete
            case let .failed(message):
                self?.scanState = .failed(message)
            }
        }
    }

    func cancelScan() {
        scanWorker?.cancel()
        scanTask?.cancel()
        scanContinuation?.finish()
        scanWorker = nil
        scanTask = nil
        scanContinuation = nil
        scanState = folders.isEmpty ? .idle : .complete
    }

    func applyPreviewFixture() {
        overviewTask?.cancel()
        cancelScan()
        volume = StorageVolumeSnapshot(
            totalBytes: 1_000_000_000_000,
            availableBytes: 284_000_000_000
        )
        let home = FileManager.default.homeDirectoryForCurrentUser
        folders = [
            previewFolder(
                id: "developer",
                name: "Developer",
                path: "Library/Developer",
                bytes: 82_400_000_000,
                fileCount: 48_302,
                home: home
            ),
            previewFolder(
                id: "downloads",
                name: "Downloads",
                path: "Downloads",
                bytes: 31_700_000_000,
                fileCount: 1_284,
                home: home
            ),
            previewFolder(
                id: "caches",
                name: "Caches",
                path: "Library/Caches",
                bytes: 18_900_000_000,
                fileCount: 24_109,
                home: home
            ),
            previewFolder(
                id: "documents",
                name: "Documents",
                path: "Documents",
                bytes: 9_600_000_000,
                fileCount: 3_876,
                home: home
            )
        ]
        scanProgress = StorageScanProgress(
            folders: folders,
            activeLocationID: nil,
            completedLocationCount: folders.count,
            totalLocationCount: folders.count
        )
        scanState = .complete
    }

    func applyScanningPreviewFixture() {
        applyPreviewFixture()
        folders = Array(folders.prefix(3))
        scanProgress = StorageScanProgress(
            folders: folders,
            activeLocationID: "caches",
            completedLocationCount: 2,
            totalLocationCount: 8
        )
        scanState = .scanning
    }

    deinit {
        overviewTask?.cancel()
        scanWorker?.cancel()
        scanTask?.cancel()
        scanContinuation?.finish()
    }

    private func previewFolder(
        id: String,
        name: String,
        path: String,
        bytes: UInt64,
        fileCount: Int,
        home: URL
    ) -> StorageFolderUsage {
        StorageFolderUsage(
            id: id,
            name: name,
            url: home.appending(path: path),
            bytes: bytes,
            fileCount: fileCount,
            status: .available
        )
    }
}

private enum StorageVolumeLoadOutcome: Sendable {
    case loaded(StorageVolumeSnapshot)
    case failed(String)

    init(_ load: () throws -> StorageVolumeSnapshot) {
        do {
            self = .loaded(try load())
        } catch {
            self = .failed(error.localizedDescription)
        }
    }
}

private enum StorageFolderLoadOutcome: Sendable {
    case loaded([StorageFolderUsage])
    case failed(String)

    init(_ load: () throws -> [StorageFolderUsage]) {
        do {
            self = .loaded(try load())
        } catch is CancellationError {
            self = .failed("Storage scan was cancelled.")
        } catch {
            self = .failed(error.localizedDescription)
        }
    }
}
