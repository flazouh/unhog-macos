import Foundation

public struct ProcessIdentity: Hashable, Sendable {
    public let pid: Int32
    public let startedAtMicroseconds: UInt64

    public init(pid: Int32, startedAtMicroseconds: UInt64) {
        self.pid = pid
        self.startedAtMicroseconds = startedAtMicroseconds
    }
}

public enum ProcessTag: Hashable, Sendable {
    case playwright
    case typeScript
    case nx
}

public struct ProcessSample: Hashable, Sendable {
    public let identity: ProcessIdentity
    public let parentPID: Int32
    public let ownerUID: UInt32
    public let name: String
    public let executablePath: String
    public let cpuPercent: Double
    public let memoryBytes: UInt64
    public let tags: Set<ProcessTag>

    public init(
        identity: ProcessIdentity,
        parentPID: Int32,
        ownerUID: UInt32,
        name: String,
        executablePath: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        tags: Set<ProcessTag> = []
    ) {
        self.identity = identity
        self.parentPID = parentPID
        self.ownerUID = ownerUID
        self.name = name
        self.executablePath = executablePath
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.tags = tags
    }
}

public enum ProcessFamilyKind: Hashable, Sendable {
    case playwright
    case typeScript
    case nx
    case application(String)

    public var displayName: String {
        switch self {
        case .playwright:
            "Playwright"
        case .typeScript:
            "TypeScript servers"
        case .nx:
            "Nx"
        case let .application(name):
            name
        }
    }
}

public struct ProcessGroupID: Hashable, Sendable {
    public let kind: ProcessFamilyKind
    public let rootPID: Int32

    public init(kind: ProcessFamilyKind, rootPID: Int32) {
        self.kind = kind
        self.rootPID = rootPID
    }
}

public struct ProcessGroup: Identifiable, Hashable, Sendable {
    public let id: ProcessGroupID
    public let kind: ProcessFamilyKind
    public let displayName: String
    public let origin: String?
    public let processes: [ProcessSample]

    public init(
        id: ProcessGroupID,
        kind: ProcessFamilyKind,
        displayName: String,
        origin: String?,
        processes: [ProcessSample]
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.origin = origin
        self.processes = processes
    }

    public var cpuPercent: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    public var memoryBytes: UInt64 {
        processes.reduce(0) { partial, process in
            let (sum, overflow) = partial.addingReportingOverflow(process.memoryBytes)
            return overflow ? UInt64.max : sum
        }
    }

    public var processCount: Int {
        processes.count
    }
}
