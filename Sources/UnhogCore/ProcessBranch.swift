import Foundation

public struct ProcessBranchID: Hashable, Sendable {
    public let workloadID: ProcessGroupID
    public let root: ProcessIdentity

    public init(
        workloadID: ProcessGroupID,
        root: ProcessIdentity
    ) {
        self.workloadID = workloadID
        self.root = root
    }
}

public struct ProcessBranchFingerprint: Hashable, Sendable {
    public let processName: String
    public let executableName: String
    public let workingDirectory: String?

    public init(branch: ProcessBranch) {
        self.processName = branch.root.name.lowercased()
        self.executableName = (branch.root.executablePath as NSString)
            .lastPathComponent
            .lowercased()
        self.workingDirectory = branch.root.workingDirectory
    }
}

public struct ProcessBranch: Identifiable, Hashable, Sendable {
    public let id: ProcessBranchID
    public let root: ProcessSample
    public let processes: [ProcessSample]

    public init(
        workloadID: ProcessGroupID,
        root: ProcessSample,
        processes: [ProcessSample]
    ) {
        self.id = ProcessBranchID(
            workloadID: workloadID,
            root: root.identity
        )
        self.root = root
        self.processes = processes
    }

    public var displayName: String { root.name }
    public var processCount: Int { processes.count }
    public var memoryBytes: UInt64 {
        processes.reduce(0) { partial, process in
            let (sum, overflow) = partial.addingReportingOverflow(
                process.memoryBytes
            )
            return overflow ? .max : sum
        }
    }
    public var cpuPercent: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    public var asProcessGroup: ProcessGroup {
        ProcessGroup(
            id: ProcessGroupID(
                kind: id.workloadID.kind,
                rootPID: root.identity.pid
            ),
            kind: id.workloadID.kind,
            displayName: displayName,
            origin: nil,
            processes: processes
        )
    }
}

public struct ProcessBranchResolver: Sendable {
    public init() {}

    public func branch(
        rootedAt identity: ProcessIdentity,
        in group: ProcessGroup
    ) -> ProcessBranch? {
        guard
            let root = group.processes.first(where: {
                $0.identity == identity
            })
        else {
            return nil
        }

        let children = Dictionary(
            grouping: group.processes,
            by: \.parentPID
        )
        var queue = [root]
        var visited = Set<ProcessIdentity>()
        var members: [ProcessSample] = []

        while !queue.isEmpty {
            let process = queue.removeFirst()
            if process.identity.pid == group.id.rootPID,
                process.identity != root.identity
            {
                continue
            }
            guard visited.insert(process.identity).inserted else {
                continue
            }
            members.append(process)
            queue.append(
                contentsOf: children[process.identity.pid] ?? []
            )
        }

        return ProcessBranch(
            workloadID: group.id,
            root: root,
            processes: members
        )
    }

    public func visibleBranches(
        in group: ProcessGroup
    ) -> [ProcessBranch] {
        let memberPIDs = Set(group.processes.map(\.identity.pid))
        let topCPUIdentity = group.processes.max {
            $0.cpuPercent < $1.cpuPercent
        }?.identity
        let topMemoryIdentity = group.processes.max {
            $0.memoryBytes < $1.memoryBytes
        }?.identity
        return group.processes
            .filter {
                $0.identity.pid != group.id.rootPID
                    && ($0.parentPID == group.id.rootPID
                        || !memberPIDs.contains($0.parentPID))
            }
            .compactMap {
                branch(rootedAt: $0.identity, in: group)
            }
            .filter {
                $0.processCount > 1
                    || $0.memoryBytes >= 30_000_000
                    || $0.root.identity == topCPUIdentity
                    || $0.root.identity == topMemoryIdentity
            }
    }
}
