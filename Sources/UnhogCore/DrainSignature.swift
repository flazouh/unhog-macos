import Foundation

public struct DrainSignature: Hashable, Sendable {
    public let primarySignal: ResourceSignal
    public let cpuCores: Double
    public let cpuShare: Double
    public let logicalCoreCount: Int
    public let memoryBytes: UInt64
    public let memoryShare: Double
    public let impact: BatteryDrainEstimate

    public init(
        group: ProcessGroup,
        primarySignal: ResourceSignal,
        installedMemoryBytes: UInt64,
        logicalCoreCount: Int
    ) {
        let cores = max(0, group.cpuPercent / 100)
        let coreCount = max(1, logicalCoreCount)
        self.primarySignal = primarySignal
        self.cpuCores = cores
        self.cpuShare = min(1, cores / Double(coreCount))
        self.logicalCoreCount = coreCount
        self.memoryBytes = group.memoryBytes
        self.memoryShare =
            installedMemoryBytes > 0
            ? min(
                1,
                Double(group.memoryBytes)
                    / Double(installedMemoryBytes)
            )
            : 0
        self.impact = BatteryDrainEstimate(
            cpuPercent: group.cpuPercent
        )
    }
}
