import Foundation

public enum ExplanationConfidence: String, Hashable, Sendable {
    case medium = "Medium"
    case high = "High"
}

public struct WorkerContribution: Hashable, Sendable {
    public let name: String
    public let memoryBytes: UInt64
    public let memoryShare: Double
    public let cpuPercent: Double
}

public struct ResourceExplanation: Hashable, Sendable {
    public let workloadTitle: String
    public let runtimeName: String
    public let processChain: [String]
    public let topWorker: WorkerContribution
    public let confidence: ExplanationConfidence
}

public struct ResourceExplainer: Sendable {
    public init() {}

    public func explain(_ group: ProcessGroup) -> ResourceExplanation {
        guard let topWorker = group.processes.max(by: {
            $0.memoryBytes < $1.memoryBytes
        }) else {
            return ResourceExplanation(
                workloadTitle: group.contextLabel.map { "\($0) stack" }
                    ?? group.displayName,
                runtimeName: group.displayName,
                processChain: [group.displayName],
                topWorker: WorkerContribution(
                    name: group.displayName,
                    memoryBytes: 0,
                    memoryShare: 0,
                    cpuPercent: 0
                ),
                confidence: .medium
            )
        }
        let memoryShare = group.memoryBytes > 0
            ? Double(topWorker.memoryBytes) / Double(group.memoryBytes)
            : 0
        var chain = processChain(
            endingAt: topWorker,
            in: group
        )
        if let contextLabel = group.contextLabel {
            chain.insert(contextLabel, at: 0)
        }
        let hasStrongAttribution =
            group.contextLabel != nil && chain.count > 2

        return ResourceExplanation(
            workloadTitle: group.contextLabel.map { "\($0) stack" }
                ?? group.displayName,
            runtimeName: group.displayName,
            processChain: chain,
            topWorker: WorkerContribution(
                name: topWorker.name,
                memoryBytes: topWorker.memoryBytes,
                memoryShare: memoryShare,
                cpuPercent: topWorker.cpuPercent
            ),
            confidence: hasStrongAttribution ? .high : .medium
        )
    }

    private func processChain(
        endingAt process: ProcessSample,
        in group: ProcessGroup
    ) -> [String] {
        let byPID = Dictionary(
            uniqueKeysWithValues: group.processes.map {
                ($0.identity.pid, $0)
            }
        )
        var current: ProcessSample? = process
        var reversedNames: [String] = []
        var visited = Set<Int32>()

        while let node = current,
              visited.insert(node.identity.pid).inserted {
            reversedNames.append(node.name)
            guard node.identity.pid != group.id.rootPID else {
                break
            }
            current = byPID[node.parentPID]
        }

        return reversedNames
            .reversed()
            .reduce(into: [String]()) { names, name in
                if names.last != name {
                    names.append(name)
                }
            }
    }
}
