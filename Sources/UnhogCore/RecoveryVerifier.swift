import Foundation

public struct WorkloadFingerprint: Hashable, Sendable {
    public let kind: ProcessFamilyKind
    public let executableName: String
    public let projectPath: String?

    public init(group: ProcessGroup) {
        let root =
            group.processes.first {
                $0.identity.pid == group.id.rootPID
            } ?? group.processes.first
        let executablePath = root?.executablePath ?? ""

        self.kind = group.kind
        self.executableName = (executablePath as NSString)
            .lastPathComponent
            .lowercased()
        self.projectPath =
            executablePath.contains(".app/")
            ? nil
            : root?.workingDirectory
    }
}

public struct WorkloadResourceSnapshot: Hashable, Sendable {
    public let memoryBytes: UInt64
    public let cpuPercent: Double
    public let batteryEstimate: BatteryDrainEstimate
    public let processCount: Int

    public init(group: ProcessGroup?) {
        self.memoryBytes = group?.memoryBytes ?? 0
        self.cpuPercent = group?.cpuPercent ?? 0
        self.batteryEstimate = BatteryDrainEstimate(
            cpuPercent: group?.cpuPercent ?? 0
        )
        self.processCount = group?.processCount ?? 0
    }
}

public enum RecoveryScope: Hashable, Sendable {
    case workload
    case branch
}

public struct RecoveryReceipt: Hashable, Sendable {
    public let scope: RecoveryScope
    public let fingerprint: WorkloadFingerprint
    public let originalGroupID: ProcessGroupID
    public let successorGroupID: ProcessGroupID?
    public let displayName: String
    public let contextLabel: String?
    public let before: WorkloadResourceSnapshot
    public let after: WorkloadResourceSnapshot
    public let originalProcessCount: Int
    public let stoppedProcessCount: Int
    public let verificationDuration: TimeInterval

    public init(
        scope: RecoveryScope = .workload,
        fingerprint: WorkloadFingerprint,
        originalGroupID: ProcessGroupID,
        successorGroupID: ProcessGroupID?,
        displayName: String,
        contextLabel: String?,
        before: WorkloadResourceSnapshot,
        after: WorkloadResourceSnapshot,
        originalProcessCount: Int,
        stoppedProcessCount: Int,
        verificationDuration: TimeInterval
    ) {
        self.scope = scope
        self.fingerprint = fingerprint
        self.originalGroupID = originalGroupID
        self.successorGroupID = successorGroupID
        self.displayName = displayName
        self.contextLabel = contextLabel
        self.before = before
        self.after = after
        self.originalProcessCount = originalProcessCount
        self.stoppedProcessCount = stoppedProcessCount
        self.verificationDuration = verificationDuration
    }

    public var memoryReductionBytes: UInt64 {
        before.memoryBytes > after.memoryBytes
            ? before.memoryBytes - after.memoryBytes
            : 0
    }

    public var cpuDropPoints: Double {
        max(0, before.cpuPercent - after.cpuPercent)
    }
}

public enum RecoveryAssessment: Hashable, Sendable {
    case recovered(RecoveryReceipt)
    case restarted(RecoveryReceipt)
    case partial(
        RecoveryReceipt,
        remaining: [ProcessIdentity]
    )
}

public struct RecoveryVerifier: Sendable {
    public init() {}

    public func assess(
        original: ProcessGroup,
        currentGroups: [ProcessGroup],
        currentProcessIdentities: Set<ProcessIdentity>,
        preexistingMatchingGroupIDs: Set<ProcessGroupID> = [],
        verificationDuration: TimeInterval
    ) -> RecoveryAssessment {
        let originalIdentities = original.processes.map(\.identity)
        let remaining = originalIdentities.filter {
            currentProcessIdentities.contains($0)
        }
        let fingerprint = WorkloadFingerprint(group: original)
        let matchingGroup = currentGroups.first {
            WorkloadFingerprint(group: $0) == fingerprint
                && !preexistingMatchingGroupIDs.contains($0.id)
        }
        let receipt = RecoveryReceipt(
            fingerprint: fingerprint,
            originalGroupID: original.id,
            successorGroupID: matchingGroup?.id,
            displayName: original.displayName,
            contextLabel: original.contextLabel,
            before: WorkloadResourceSnapshot(group: original),
            after: WorkloadResourceSnapshot(group: matchingGroup),
            originalProcessCount: original.processCount,
            stoppedProcessCount: max(
                0,
                original.processCount - remaining.count
            ),
            verificationDuration: verificationDuration
        )

        if !remaining.isEmpty {
            return .partial(receipt, remaining: remaining)
        }

        if matchingGroup != nil {
            return .restarted(receipt)
        }

        return .recovered(receipt)
    }
}

public struct BranchRecoveryVerifier: Sendable {
    private let resolver = ProcessBranchResolver()

    public init() {}

    public func assess(
        original: ProcessBranch,
        currentGroups: [ProcessGroup],
        currentProcessIdentities: Set<ProcessIdentity>,
        preexistingMatchingBranchIDs: Set<ProcessBranchID> = [],
        verificationDuration: TimeInterval
    ) -> RecoveryAssessment {
        let remaining = original.processes
            .map(\.identity)
            .filter(currentProcessIdentities.contains)
        let fingerprint = ProcessBranchFingerprint(branch: original)
        let matchingBranch =
            currentGroups
            .first { $0.id == original.id.workloadID }
            .flatMap { workload in
                resolver.visibleBranches(in: workload)
                    .first {
                        $0.id != original.id
                            && !preexistingMatchingBranchIDs
                                .contains($0.id)
                            && ProcessBranchFingerprint(branch: $0)
                                == fingerprint
                    }
            }
        let originalGroup = original.asProcessGroup
        let successor = matchingBranch?.asProcessGroup
        let receipt = RecoveryReceipt(
            scope: .branch,
            fingerprint: WorkloadFingerprint(group: originalGroup),
            originalGroupID: originalGroup.id,
            successorGroupID: successor?.id,
            displayName: original.displayName,
            contextLabel: nil,
            before: WorkloadResourceSnapshot(group: originalGroup),
            after: WorkloadResourceSnapshot(group: successor),
            originalProcessCount: original.processCount,
            stoppedProcessCount: max(
                0,
                original.processCount - remaining.count
            ),
            verificationDuration: verificationDuration
        )

        if !remaining.isEmpty {
            return .partial(receipt, remaining: remaining)
        }
        return successor == nil
            ? .recovered(receipt)
            : .restarted(receipt)
    }
}
