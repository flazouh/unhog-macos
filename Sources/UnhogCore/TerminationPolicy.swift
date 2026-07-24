import Foundation

public enum TerminationCapability: Hashable, Sendable {
    case allowed
    case protected(reason: String)
}

public struct TerminationPlan: Hashable, Sendable {
    public let capability: TerminationCapability
    public let targets: [ProcessIdentity]

    public init(capability: TerminationCapability, targets: [ProcessIdentity]) {
        self.capability = capability
        self.targets = targets
    }
}

public struct TerminationPolicy: Sendable {
    private let currentUID: UInt32
    private let appPID: Int32

    public init(currentUID: UInt32, appPID: Int32) {
        self.currentUID = currentUID
        self.appPID = appPID
    }

    public func plan(for group: ProcessGroup) -> TerminationPlan {
        plan(
            processes: group.processes,
            targets: group.processes
                .map(\.identity)
                .sorted { $0.pid < $1.pid }
        )
    }

    public func plan(for branch: ProcessBranch) -> TerminationPlan {
        let depthByPID = branchDepths(branch)
        let targets = branch.processes
            .sorted {
                let left = depthByPID[$0.identity.pid] ?? 0
                let right = depthByPID[$1.identity.pid] ?? 0
                if left == right {
                    return $0.identity.pid > $1.identity.pid
                }
                return left > right
            }
            .map(\.identity)
        return plan(processes: branch.processes, targets: targets)
    }

    private func plan(
        processes: [ProcessSample],
        targets: [ProcessIdentity]
    ) -> TerminationPlan {
        if processes.contains(where: { $0.identity.pid == appPID }) {
            return TerminationPlan(
                capability: .protected(reason: "Unhog protects itself"),
                targets: []
            )
        }

        if processes.contains(where: {
            ProcessProtection.reason(
                pid: $0.identity.pid,
                name: $0.name,
                path: $0.executablePath
            ) != nil
        }) {
            return TerminationPlan(
                capability: .protected(reason: "macOS system process"),
                targets: []
            )
        }

        guard processes.allSatisfy({ $0.ownerUID == currentUID }) else {
            return TerminationPlan(
                capability: .protected(reason: "Process belongs to another user"),
                targets: []
            )
        }

        return TerminationPlan(
            capability: .allowed,
            targets: targets
        )
    }

    private func branchDepths(
        _ branch: ProcessBranch
    ) -> [Int32: Int] {
        let byPID = Dictionary(
            uniqueKeysWithValues: branch.processes.map {
                ($0.identity.pid, $0)
            }
        )
        var result: [Int32: Int] = [:]
        for process in branch.processes {
            var depth = 0
            var current = process
            var visited = Set<Int32>()
            while current.identity != branch.root.identity,
                  visited.insert(current.identity.pid).inserted,
                  let parent = byPID[current.parentPID] {
                depth += 1
                current = parent
            }
            result[process.identity.pid] = depth
        }
        return result
    }
}

enum ProcessProtection {
    private static let protectedNames: Set<String> = [
        "kernel_task",
        "launchd",
        "loginwindow",
        "windowserver",
        "systemuiserver"
    ]

    static func reason(pid: Int32, name: String, path: String) -> String? {
        if pid <= 1
            || protectedNames.contains(name.lowercased())
            || isProtectedSystemPath(path) {
            return "macOS system process"
        }
        return nil
    }

    private static func isProtectedSystemPath(_ path: String) -> Bool {
        path.hasPrefix("/System/Library/")
            || path.hasPrefix("/usr/libexec/")
            || path.hasPrefix("/usr/sbin/")
            || path.hasPrefix("/sbin/")
    }
}
