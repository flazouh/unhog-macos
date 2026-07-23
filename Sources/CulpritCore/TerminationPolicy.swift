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
        if group.processes.contains(where: { $0.identity.pid == appPID }) {
            return TerminationPlan(
                capability: .protected(reason: "Culprit protects itself"),
                targets: []
            )
        }

        if group.processes.contains(where: {
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

        guard group.processes.allSatisfy({ $0.ownerUID == currentUID }) else {
            return TerminationPlan(
                capability: .protected(reason: "Process belongs to another user"),
                targets: []
            )
        }

        return TerminationPlan(
            capability: .allowed,
            targets: group.processes
                .map(\.identity)
                .sorted { $0.pid < $1.pid }
        )
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
