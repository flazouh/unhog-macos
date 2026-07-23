import Testing
@testable import CulpritCore

@Suite("Verified workload recovery")
struct RecoveryVerifierTests {
    @Test("A matching workload with a new root PID is reported as restarted")
    func detectsRestartAcrossPIDChange() {
        let original = group(
            rootPID: 100,
            workerPID: 101,
            memory: 3_860_000_000,
            cpu: 184
        )
        let restarted = group(
            rootPID: 200,
            workerPID: 201,
            memory: 1_200_000_000,
            cpu: 72
        )

        let assessment = RecoveryVerifier().assess(
            original: original,
            currentGroups: [restarted],
            currentProcessIdentities: Set(restarted.processes.map(\.identity)),
            verificationDuration: 2
        )

        guard case let .restarted(receipt) = assessment else {
            Issue.record("Expected a restarted recovery receipt")
            return
        }

        #expect(receipt.originalGroupID == original.id)
        #expect(receipt.successorGroupID == restarted.id)
        #expect(receipt.before.memoryBytes == 3_860_000_000)
        #expect(receipt.after.memoryBytes == 1_200_000_000)
        #expect(receipt.stoppedProcessCount == 2)
    }

    @Test("A vanished workload produces a measured recovery receipt")
    func reportsMeasuredRecovery() {
        let original = group(
            rootPID: 100,
            workerPID: 101,
            memory: 3_860_000_000,
            cpu: 184
        )

        let assessment = RecoveryVerifier().assess(
            original: original,
            currentGroups: [],
            currentProcessIdentities: [],
            verificationDuration: 2
        )

        guard case let .recovered(receipt) = assessment else {
            Issue.record("Expected a recovered receipt")
            return
        }

        #expect(receipt.after.memoryBytes == 0)
        #expect(receipt.memoryReductionBytes == 3_860_000_000)
        #expect(receipt.cpuDropPoints == 184)
        #expect(receipt.stoppedProcessCount == 2)
        #expect(receipt.contextLabel == "FluentAI · ds-rebuild")
    }

    @Test("An existing sibling workload is not mistaken for a restart")
    func ignoresPreexistingSibling() {
        let original = group(
            rootPID: 100,
            workerPID: 101,
            memory: 3_860_000_000,
            cpu: 184
        )
        let sibling = group(
            rootPID: 300,
            workerPID: 301,
            memory: 1_400_000_000,
            cpu: 40
        )

        let assessment = RecoveryVerifier().assess(
            original: original,
            currentGroups: [sibling],
            currentProcessIdentities: Set(sibling.processes.map(\.identity)),
            preexistingMatchingGroupIDs: [sibling.id],
            verificationDuration: 2
        )

        guard case .recovered = assessment else {
            Issue.record("The unchanged sibling should be ignored")
            return
        }
    }

    private func group(
        rootPID: Int32,
        workerPID: Int32,
        memory: UInt64,
        cpu: Double
    ) -> ProcessGroup {
        let kind = ProcessFamilyKind.application("bun")
        let root = sample(
            pid: rootPID,
            parentPID: 1,
            name: "bun",
            path: "/Users/alex/.bun/bin/bun",
            memory: memory / 2,
            cpu: cpu / 2
        )
        let worker = sample(
            pid: workerPID,
            parentPID: rootPID,
            name: "esbuild",
            path: "/Users/alex/Documents/fluentai/node_modules/esbuild",
            memory: memory - memory / 2,
            cpu: cpu - cpu / 2
        )
        return ProcessGroup(
            id: ProcessGroupID(kind: kind, rootPID: rootPID),
            kind: kind,
            displayName: "bun",
            origin: nil,
            processes: [root, worker]
        )
    }

    private func sample(
        pid: Int32,
        parentPID: Int32,
        name: String,
        path: String,
        memory: UInt64,
        cpu: Double
    ) -> ProcessSample {
        ProcessSample(
            identity: ProcessIdentity(
                pid: pid,
                startedAtMicroseconds: UInt64(pid) * 1_000
            ),
            parentPID: parentPID,
            ownerUID: 501,
            name: name,
            executablePath: path,
            workingDirectory:
                "/Users/alex/Documents/fluentai.worktrees/ds-rebuild",
            cpuPercent: cpu,
            memoryBytes: memory
        )
    }
}
