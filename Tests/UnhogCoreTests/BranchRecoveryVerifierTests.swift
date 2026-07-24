import Testing
@testable import UnhogCore

@Suite("Verified branch recovery")
struct BranchRecoveryVerifierTests {
    @Test("A vanished branch is recovered without calling the parent stopped")
    func recoveredBranch() throws {
        let original = try branch(pid: 20, startedAt: 20_000)

        let assessment = BranchRecoveryVerifier().assess(
            original: original,
            currentGroups: [],
            currentProcessIdentities: [],
            verificationDuration: 2
        )

        guard case let .recovered(receipt) = assessment else {
            Issue.record("Expected recovered branch")
            return
        }
        #expect(receipt.scope == .branch)
        #expect(receipt.displayName == "Chromium")
        #expect(receipt.stoppedProcessCount == 1)
    }

    @Test("A surviving original identity is partial")
    func partialBranch() throws {
        let original = try branch(pid: 20, startedAt: 20_000)

        let assessment = BranchRecoveryVerifier().assess(
            original: original,
            currentGroups: [],
            currentProcessIdentities: [original.root.identity],
            verificationDuration: 2
        )

        guard case let .partial(_, remaining) = assessment else {
            Issue.record("Expected partial branch stop")
            return
        }
        #expect(remaining == [original.root.identity])
    }

    @Test("A matching new branch is reported as restarted")
    func restartedBranch() throws {
        let original = try branch(pid: 20, startedAt: 20_000)
        let successorGroup = group(pid: 30, startedAt: 30_000)

        let assessment = BranchRecoveryVerifier().assess(
            original: original,
            currentGroups: [successorGroup],
            currentProcessIdentities: Set(
                successorGroup.processes.map(\.identity)
            ),
            verificationDuration: 2
        )

        guard case let .restarted(receipt) = assessment else {
            Issue.record("Expected restarted branch")
            return
        }
        #expect(receipt.scope == .branch)
        #expect(receipt.successorGroupID?.rootPID == 30)
    }

    private func branch(
        pid: Int32,
        startedAt: UInt64
    ) throws -> ProcessBranch {
        let workload = group(pid: pid, startedAt: startedAt)
        let process = try #require(
            workload.processes.first { $0.identity.pid == pid }
        )
        return try #require(
            ProcessBranchResolver().branch(
                rootedAt: process.identity,
                in: workload
            )
        )
    }

    private func group(
        pid: Int32,
        startedAt: UInt64
    ) -> ProcessGroup {
        let kind = ProcessFamilyKind.playwright
        let root = ProcessSample(
            identity: .init(pid: 10, startedAtMicroseconds: 10_000),
            parentPID: 1,
            ownerUID: 501,
            name: "Playwright",
            executablePath: "/tools/playwright",
            cpuPercent: 10,
            memoryBytes: 50_000_000
        )
        let chromium = ProcessSample(
            identity: .init(
                pid: pid,
                startedAtMicroseconds: startedAt
            ),
            parentPID: 10,
            ownerUID: 501,
            name: "Chromium",
            executablePath: "/tools/chromium",
            workingDirectory: "/project",
            cpuPercent: 100,
            memoryBytes: 200_000_000
        )
        return ProcessGroup(
            id: .init(kind: kind, rootPID: 10),
            kind: kind,
            displayName: "Playwright",
            origin: nil,
            processes: [root, chromium]
        )
    }
}
