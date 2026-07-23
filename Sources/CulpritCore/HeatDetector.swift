import Foundation

public enum HeatSeverity: Int, Comparable, Sendable {
    case warning = 1
    case critical = 2

    public static func < (lhs: HeatSeverity, rhs: HeatSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct HeatThresholds: Hashable, Sendable {
    public var warningCPUPercent: Double
    public var criticalCPUPercent: Double
    public var warningMemoryBytes: UInt64
    public var criticalMemoryBytes: UInt64
    public var sustainedFor: TimeInterval

    public init(
        warningCPUPercent: Double = 150,
        criticalCPUPercent: Double = 300,
        warningMemoryBytes: UInt64 = 1_500_000_000,
        criticalMemoryBytes: UInt64 = 3_000_000_000,
        sustainedFor: TimeInterval = 20
    ) {
        self.warningCPUPercent = warningCPUPercent
        self.criticalCPUPercent = criticalCPUPercent
        self.warningMemoryBytes = warningMemoryBytes
        self.criticalMemoryBytes = criticalMemoryBytes
        self.sustainedFor = sustainedFor
    }
}

public struct HeatIncident: Identifiable, Hashable, Sendable {
    public let id: ProcessGroupID
    public let group: ProcessGroup
    public let severity: HeatSeverity
    public let beganAt: Date
    public let duration: TimeInterval
    public let reason: String
}

public struct HeatDetector: Sendable {
    private enum Metric: Hashable, Sendable {
        case warningCPU
        case criticalCPU
        case warningMemory
        case criticalMemory

        var severity: HeatSeverity {
            switch self {
            case .warningCPU, .warningMemory:
                .warning
            case .criticalCPU, .criticalMemory:
                .critical
            }
        }
    }

    private struct PressureKey: Hashable, Sendable {
        let groupID: ProcessGroupID
        let metric: Metric
    }

    public var thresholds: HeatThresholds
    private var pressureBeganAt: [PressureKey: Date] = [:]

    public init(thresholds: HeatThresholds = .init()) {
        self.thresholds = thresholds
    }

    public mutating func evaluate(
        _ groups: [ProcessGroup],
        at date: Date = Date()
    ) -> [HeatIncident] {
        let liveIDs = Set(groups.map(\.id))
        pressureBeganAt = pressureBeganAt.filter {
            liveIDs.contains($0.key.groupID)
        }

        var incidents: [HeatIncident] = []

        for group in groups {
            let conditions: [(Metric, Bool)] = [
                (.warningCPU, group.cpuPercent >= thresholds.warningCPUPercent),
                (.criticalCPU, group.cpuPercent >= thresholds.criticalCPUPercent),
                (.warningMemory, group.memoryBytes >= thresholds.warningMemoryBytes),
                (.criticalMemory, group.memoryBytes >= thresholds.criticalMemoryBytes)
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
                HeatIncident(
                    id: group.id,
                    group: group,
                    severity: strongest.metric.severity,
                    beganAt: strongest.beganAt,
                    duration: strongest.duration,
                    reason: reason(for: strongest.metric)
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
        case .warningMemory: 0
        case .warningCPU: 1
        case .criticalMemory: 2
        case .criticalCPU: 3
        }
    }

    private func reason(for metric: Metric) -> String {
        let seconds = Int(thresholds.sustainedFor.rounded())

        switch metric {
        case .warningCPU:
            return cpuReason(thresholds.warningCPUPercent, seconds: seconds)
        case .criticalCPU:
            return cpuReason(thresholds.criticalCPUPercent, seconds: seconds)
        case .warningMemory:
            return memoryReason(thresholds.warningMemoryBytes, seconds: seconds)
        case .criticalMemory:
            return memoryReason(thresholds.criticalMemoryBytes, seconds: seconds)
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
