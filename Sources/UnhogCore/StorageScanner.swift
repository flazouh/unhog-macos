import Foundation

public struct StorageVolumeSnapshot: Equatable, Sendable {
    public let totalBytes: UInt64
    public let availableBytes: UInt64

    public init(totalBytes: UInt64, availableBytes: UInt64) {
        self.totalBytes = totalBytes
        self.availableBytes = min(totalBytes, availableBytes)
    }

    public var usedBytes: UInt64 {
        totalBytes - availableBytes
    }

    public var usedShare: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

public struct StorageLocation: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let url: URL

    public init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }

    public static func commonLocations(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [StorageLocation] {
        [
            StorageLocation(
                id: "downloads",
                name: "Downloads",
                url: homeDirectory.appending(path: "Downloads")
            ),
            StorageLocation(
                id: "applications",
                name: "Applications",
                url: URL(filePath: "/Applications")
            ),
            StorageLocation(
                id: "documents",
                name: "Documents",
                url: homeDirectory.appending(path: "Documents")
            ),
            StorageLocation(
                id: "pictures",
                name: "Pictures",
                url: homeDirectory.appending(path: "Pictures")
            ),
            StorageLocation(
                id: "movies",
                name: "Movies",
                url: homeDirectory.appending(path: "Movies")
            ),
            StorageLocation(
                id: "music",
                name: "Music",
                url: homeDirectory.appending(path: "Music")
            ),
            StorageLocation(
                id: "developer",
                name: "Developer",
                url: homeDirectory.appending(path: "Library/Developer")
            ),
            StorageLocation(
                id: "caches",
                name: "Caches",
                url: homeDirectory.appending(path: "Library/Caches")
            )
        ]
    }
}

public enum StorageFolderStatus: Equatable, Sendable {
    case available
    case unavailable
}

public struct StorageFolderUsage: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let bytes: UInt64
    public let fileCount: Int
    public let status: StorageFolderStatus

    public init(
        id: String,
        name: String,
        url: URL,
        bytes: UInt64,
        fileCount: Int,
        status: StorageFolderStatus
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.bytes = bytes
        self.fileCount = fileCount
        self.status = status
    }
}

public struct StorageScanner: Sendable {
    public init() {}

    public func volumeSnapshot(
        for url: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> StorageVolumeSnapshot {
        let attributes = try FileManager.default.attributesOfFileSystem(
            forPath: url.path
        )
        let total = (
            attributes[.systemSize] as? NSNumber
        )?.uint64Value ?? 0
        let available = (
            attributes[.systemFreeSize] as? NSNumber
        )?.uint64Value ?? 0
        return StorageVolumeSnapshot(
            totalBytes: total,
            availableBytes: available
        )
    }

    public func scan(
        _ locations: [StorageLocation]
    ) throws -> [StorageFolderUsage] {
        var results: [StorageFolderUsage] = []
        results.reserveCapacity(locations.count)

        for location in locations {
            try Task.checkCancellation()
            results.append(try usage(for: location))
        }

        return results.sorted { left, right in
            if left.status != right.status {
                return left.status == .available
            }
            if left.bytes != right.bytes {
                return left.bytes > right.bytes
            }
            return left.name.localizedStandardCompare(right.name)
                == .orderedAscending
        }
    }

    private func usage(
        for location: StorageLocation
    ) throws -> StorageFolderUsage {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: location.url.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue,
        fileManager.isReadableFile(atPath: location.url.path),
        let enumerator = fileManager.enumerator(
            at: location.url,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ],
            options: []
        ) else {
            return unavailableUsage(for: location)
        }

        var bytes: UInt64 = 0
        var fileCount = 0
        var visitedCount = 0

        while let fileURL = enumerator.nextObject() as? URL {
            visitedCount += 1
            if visitedCount.isMultiple(of: 256) {
                try Task.checkCancellation()
            }

            guard let values = try? fileURL.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey
                ]
            ) else {
                continue
            }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true else { continue }

            let fileBytes = UInt64(max(0, values.fileSize ?? 0))
            let addition = bytes.addingReportingOverflow(fileBytes)
            bytes = addition.overflow ? UInt64.max : addition.partialValue
            fileCount += 1
        }

        return StorageFolderUsage(
            id: location.id,
            name: location.name,
            url: location.url,
            bytes: bytes,
            fileCount: fileCount,
            status: .available
        )
    }

    private func unavailableUsage(
        for location: StorageLocation
    ) -> StorageFolderUsage {
        StorageFolderUsage(
            id: location.id,
            name: location.name,
            url: location.url,
            bytes: 0,
            fileCount: 0,
            status: .unavailable
        )
    }
}
