import Foundation

public struct ProcessGrouper: Sendable {
    public init() {}

    public func groups(from samples: [ProcessSample]) -> [ProcessGroup] {
        let byPID = Dictionary(uniqueKeysWithValues: samples.map { ($0.identity.pid, $0) })
        var claimedPIDs = Set<Int32>()
        var result: [ProcessGroup] = []

        for specialKind in [ProcessFamilyKind.playwright, .typeScript, .nx] {
            let allMembers =
                samples
                .filter { classify($0) == specialKind }
                .sorted { $0.identity.pid < $1.identity.pid }

            guard !allMembers.isEmpty else { continue }
            claimedPIDs.formUnion(allMembers.map(\.identity.pid))

            let allMemberPIDs = Set(allMembers.map(\.identity.pid))
            let sessions = Dictionary(grouping: allMembers) { process in
                specialRootPID(
                    for: process,
                    memberPIDs: allMemberPIDs,
                    byPID: byPID
                )
            }

            for (sessionPID, members) in sessions {
                let root = byPID[sessionPID] ?? members[0]
                let parent = byPID[root.parentPID]

                result.append(
                    ProcessGroup(
                        id: ProcessGroupID(kind: specialKind, rootPID: sessionPID),
                        kind: specialKind,
                        displayName: specialKind.displayName,
                        origin: parent.map { "Started by \($0.name)" },
                        processes: members.sorted { $0.identity.pid < $1.identity.pid }
                    )
                )
            }
        }

        let ordinary = samples.filter { !claimedPIDs.contains($0.identity.pid) }
        let ordinaryByPID = Dictionary(uniqueKeysWithValues: ordinary.map { ($0.identity.pid, $0) })
        let grouped = Dictionary(grouping: ordinary) { process in
            ordinaryRootPID(for: process, byPID: ordinaryByPID)
        }

        for (rootPID, members) in grouped {
            guard let root = ordinaryByPID[rootPID] else { continue }
            let kind = ProcessFamilyKind.application(root.name)
            result.append(
                ProcessGroup(
                    id: ProcessGroupID(kind: kind, rootPID: rootPID),
                    kind: kind,
                    displayName: root.name,
                    origin: nil,
                    processes: members.sorted { $0.identity.pid < $1.identity.pid }
                )
            )
        }

        return result.sorted {
            if $0.cpuPercent == $1.cpuPercent {
                return $0.memoryBytes > $1.memoryBytes
            }
            return $0.cpuPercent > $1.cpuPercent
        }
    }

    private func classify(_ process: ProcessSample) -> ProcessFamilyKind? {
        let tags = process.tags.union(
            ProcessClassifier.tags(
                name: process.name,
                path: process.executablePath
            )
        )

        if tags.contains(.playwright) {
            return .playwright
        }

        if tags.contains(.typeScript) {
            return .typeScript
        }

        if tags.contains(.nx) || process.name.lowercased() == "nx" {
            return .nx
        }

        return nil
    }

    private func ordinaryRootPID(
        for process: ProcessSample,
        byPID: [Int32: ProcessSample]
    ) -> Int32 {
        var current = process
        var visited = Set<Int32>()

        while current.parentPID > 1,
            visited.insert(current.identity.pid).inserted,
            let parent = byPID[current.parentPID],
            parent.ownerUID == current.ownerUID
        {
            current = parent
        }

        return current.identity.pid
    }

    private func specialRootPID(
        for process: ProcessSample,
        memberPIDs: Set<Int32>,
        byPID: [Int32: ProcessSample]
    ) -> Int32 {
        var root = process
        var visited = Set<Int32>()

        while memberPIDs.contains(root.parentPID),
            visited.insert(root.identity.pid).inserted,
            let parent = byPID[root.parentPID]
        {
            root = parent
        }

        return root.identity.pid
    }
}
