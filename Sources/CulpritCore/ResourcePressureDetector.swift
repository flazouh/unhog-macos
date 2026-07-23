import Foundation

public enum ResourceSeverity: Int, Comparable, Sendable {
    case elevated = 1
    case high = 2

    public static func < (lhs: ResourceSeverity, rhs: ResourceSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ResourceThresholds: Hashable, Sendable {
    public var elevatedCPUPercent: Double
    public var highCPUPercent: Double
    public var elevatedMemoryBytes: UInt64
    public var highMemoryBytes: UInt64
    public var developerToolElevatedMemoryBytes: UInt64
    public var developerToolHighMemoryBytes: UInt64
    public var sustainedFor: TimeInterval

    public init(
        elevatedCPUPercent: Double = 150,
        highCPUPercent: Double = 300,
        elevatedMemoryBytes: UInt64 = 1_500_000_000,
        highMemoryBytes: UInt64 = 3_000_000_000,
        developerToolElevatedMemoryBytes: UInt64 = 3_000_000_000,
        developerToolHighMemoryBytes: UInt64 = 6_000_000_000,
        sustainedFor: TimeInterval = 20
    ) {
        self.elevatedCPUPercent = elevatedCPUPercent
        self.highCPUPercent = highCPUPercent
        self.elevatedMemoryBytes = elevatedMemoryBytes
        self.highMemoryBytes = highMemoryBytes
        self.developerToolElevatedMemoryBytes =
            developerToolElevatedMemoryBytes
        self.developerToolHighMemoryBytes = developerToolHighMemoryBytes
        self.sustainedFor = sustainedFor
    }

    public static func forInstalledMemory(
        _ installedMemoryBytes: UInt64
    ) -> ResourceThresholds {
        ResourceThresholds(
            elevatedMemoryBytes: max(
                4_000_000_000,
                installedMemoryBytes / 5
            ),
            highMemoryBytes: max(
                8_000_000_000,
                installedMemoryBytes / 20 * 7
            )
        )
    }
}

public enum ResourceSignal: Hashable, Sendable {
    case cpu
    case memory
}

public struct ResourceIncident: Identifiable, Hashable, Sendable {
    public let id: ProcessGroupID
    public let group: ProcessGroup
    public let severity: ResourceSeverity
    public let signal: ResourceSignal
    public let beganAt: Date
    public let duration: TimeInterval
    public let reason: String
}

public struct ResourcePressureDetector: Sendable {
    private enum Metric: Hashable, Sendable {
        case elevatedCPU
        case highCPU
        case elevatedMemory
        case highMemory

        var severity: ResourceSeverity {
            switch self {
            case .elevatedCPU, .elevatedMemory:
                .elevated
            case .highCPU, .highMemory:
                .high
            }
        }
    }

    private struct PressureKey: Hashable, Sendable {
        let groupID: ProcessGroupID
        let metric: Metric
    }

    public var thresholds: ResourceThresholds
    private var pressureBeganAt: [PressureKey: Date] = [:]

    public init(thresholds: ResourceThresholds = .init()) {
        self.thresholds = thresholds
    }

    public mutating func evaluate(
        _ groups: [ProcessGroup],
        at date: Date = Date()
    ) -> [ResourceIncident] {
        let liveIDs = Set(groups.map(\.id))
        pressureBeganAt = pressureBeganAt.filter {
            liveIDs.contains($0.key.groupID)
        }

        var incidents: [ResourceIncident] = []

        for group in groups {
            let conditions: [(Metric, Bool)] = [
                (.elevatedCPU, group.cpuPercent >= thresholds.elevatedCPUPercent),
                (.highCPU, group.cpuPercent >= thresholds.highCPUPercent),
                (
                    .elevatedMemory,
                    group.memoryBytes >= memoryThreshold(
                        for: group,
                        severity: .elevated
                    )
                ),
                (
                    .highMemory,
                    group.memoryBytes >= memoryThreshold(
                        for: group,
                        severity: .high
                    )
                )
            ]

            var sustained: [(metric: Metric, beganAt: Date, duration: TimeInterval)] = []

            for (metric, isActive) in conditions {
                let key = PressureKey(groupID: group.id, metric: metric)
                guard isActive else {
                    pressureBeganAt[key] = nil
                    continue
                }

                let beganAt = pressureBeganAt[key] ?? date
                pressureBeganAt[key] = beganAt
                let duration = date.timeIntervalSince(beganAt)
                if duration >= thresholds.sustainedFor {
                    sustained.append((metric, beganAt, duration))
                }
            }

            guard let strongest = sustained.max(by: {
                if $0.metric.severity == $1.metric.severity {
                    return metricPriority($0.metric) < metricPriority($1.metric)
                }
                return $0.metric.severity < $1.metric.severity
            }) else {
                continue
            }

            incidents.append(
                ResourceIncident(
                    id: group.id,
                    group: group,
                    severity: strongest.metric.severity,
                    signal: signal(for: strongest.metric),
                    beganAt: strongest.beganAt,
                    duration: strongest.duration,
                    reason: reason(
                        for: strongest.metric,
                        group: group
                    )
                )
            )
        }

        return incidents.sorted {
            if $0.severity == $1.severity {
                return $0.group.cpuPercent > $1.group.cpuPercent
            }
            return $0.severity > $1.severity
        }
    }

    private func metricPriority(_ metric: Metric) -> Int {
        switch metric {
        case .elevatedMemory: 0
        case .elevatedCPU: 1
        case .highMemory: 2
        case .highCPU: 3
        }
    }

    private func memoryThreshold(
        for group: ProcessGroup,
        severity: ResourceSeverity
    ) -> UInt64 {
        guard isDeveloperTool(group) else {
            return severity == .high
                ? thresholds.highMemoryBytes
                : thresholds.elevatedMemoryBytes
        }
        return severity == .high
            ? min(
                thresholds.highMemoryBytes,
                thresholds.developerToolHighMemoryBytes
            )
            : min(
                thresholds.elevatedMemoryBytes,
                thresholds.developerToolElevatedMemoryBytes
            )
    }

    private func isDeveloperTool(_ group: ProcessGroup) -> Bool {
        switch group.kind {
        case .playwright, .typeScript, .nx:
            return true
        case .application:
            let root = group.processes.first {
                $0.identity.pid == group.id.rootPID
            } ?? group.processes.first
            let executable = (
                root?.executablePath as NSString?
            )?.lastPathComponent.lowercased()
            return [
                "bun",
                "deno",
                "esbuild",
                "node",
                "nx",
                "tsserver",
                "typescript-language-server"
            ].contains(executable)
        }
    }

    private func signal(for metric: Metric) -> ResourceSignal {
        switch metric {
        case .elevatedCPU, .highCPU:
            .cpu
        case .elevatedMemory, .highMemory:
            .memory
        }
    }

    private func reason(
        for metric: Metric,
        group: ProcessGroup
    ) -> String {
        let seconds = Int(thresholds.sustainedFor.rounded())

        switch metric {
        case .elevatedCPU:
            return cpuReason(thresholds.elevatedCPUPercent, seconds: seconds)
        case .highCPU:
            return cpuReason(thresholds.highCPUPercent, seconds: seconds)
        case .elevatedMemory:
            return memoryReason(
                memoryThreshold(for: group, severity: .elevated),
                seconds: seconds
            )
        case .highMemory:
            return memoryReason(
                memoryThreshold(for: group, severity: .high),
                seconds: seconds
            )
        }
    }

    private func cpuReason(_ threshold: Double, seconds: Int) -> String {
        "CPU stayed above \(Int(threshold.rounded()))% for \(seconds) seconds."
    }

    private func memoryReason(_ threshold: UInt64, seconds: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        let memory = formatter.string(fromByteCount: Int64(clamping: threshold))
        return "Memory stayed above \(memory) for \(seconds) seconds."
    }
}
