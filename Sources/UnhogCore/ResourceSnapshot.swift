import Foundation

public enum BatteryDrainEstimate: String, Hashable, Sendable {
    case low = "Low"
    case elevated = "Elevated"
    case high = "High"

    public init(cpuPercent: Double) {
        switch max(0, cpuPercent) {
        case 80...:
            self = .high
        case 15..<80:
            self = .elevated
        default:
            self = .low
        }
    }
}

public struct AppMemorySegment: Identifiable, Hashable, Sendable {
    public let id: ProcessGroupID
    public let group: ProcessGroup
    public let bytes: UInt64
    public let shareOfInstalledRAM: Double

    public init(
        group: ProcessGroup,
        installedBytes: UInt64
    ) {
        self.id = group.id
        self.group = group
        self.bytes = group.memoryBytes
        self.shareOfInstalledRAM =
            installedBytes > 0
            ? min(1, Double(group.memoryBytes) / Double(installedBytes))
            : 0
    }
}

public struct MemoryComposition: Hashable, Sendable {
    public let installedBytes: UInt64
    public let segments: [AppMemorySegment]
    public let hasOverlappingProcessTotals: Bool

    public init(
        installedBytes: UInt64,
        groups: [ProcessGroup],
        maximumVisibleSegments: Int = 5,
        prioritizedGroupID: ProcessGroupID? = nil
    ) {
        self.installedBytes = installedBytes
        var remainingBytes = installedBytes
        var visibleSegments: [AppMemorySegment] = []
        var foundOverlap = false

        let candidates =
            groups
            .sorted { left, right in
                if left.id == prioritizedGroupID {
                    return right.id != prioritizedGroupID
                }
                if right.id == prioritizedGroupID {
                    return false
                }
                return left.memoryBytes > right.memoryBytes
            }
            .prefix(max(0, maximumVisibleSegments))

        for group in candidates {
            guard group.memoryBytes <= remainingBytes else {
                foundOverlap = true
                continue
            }
            visibleSegments.append(
                AppMemorySegment(
                    group: group,
                    installedBytes: installedBytes
                )
            )
            remainingBytes -= group.memoryBytes
        }

        self.segments = visibleSegments
        self.hasOverlappingProcessTotals = foundOverlap
    }

    public var attributedBytes: UInt64 {
        segments.reduce(0) { partial, segment in
            let (sum, overflow) = partial.addingReportingOverflow(segment.bytes)
            return overflow ? UInt64.max : sum
        }
    }

    public var remainderBytes: UInt64 {
        installedBytes > attributedBytes
            ? installedBytes - attributedBytes
            : 0
    }

    public var remainderShare: Double {
        guard installedBytes > 0 else { return 0 }
        return Double(remainderBytes) / Double(installedBytes)
    }
}
