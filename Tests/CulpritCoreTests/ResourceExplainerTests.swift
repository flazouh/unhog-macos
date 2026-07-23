import Testing
@testable import CulpritCore

@Suite("Resource explanations")
struct ResourceExplainerTests {
    @Test("The explanation identifies the project chain and top worker")
    func explainsDeveloperStack() {
        let group = developerGroup()

        let explanation = ResourceExplainer().explain(group)

        #expect(explanation.workloadTitle == "FluentAI · ds-rebuild stack")
        #expect(
            explanation.processChain
                == ["FluentAI · ds-rebuild", "bun", "esbuild"]
        )
        #expect(explanation.topWorker.name == "esbuild")
        #expect(explanation.topWorker.memoryBytes == 3_000_000_000)
        #expect(explanation.topWorker.memoryShare > 0.77)
        #expect(explanation.confidence == .high)
    }

    @Test("Project context can be excluded from every explanation field")
    func hidesProjectContext() {
        let group = developerGroup()

        let explanation = ResourceExplainer().explain(
            group,
            includesProjectContext: false
        )

        #expect(!explanation.workloadTitle.contains("FluentAI"))
        #expect(!explanation.processChain.contains { $0.contains("FluentAI") })
    }

    private func developerGroup() -> ProcessGroup {
        let kind = ProcessFamilyKind.application("bun")
        let root = sample(
            pid: 100,
            parentPID: 1,
            name: "bun",
            memory: 860_000_000,
            cpu: 20
        )
        let worker = sample(
            pid: 101,
            parentPID: 100,
            name: "esbuild",
            memory: 3_000_000_000,
            cpu: 164
        )
        return ProcessGroup(
            id: ProcessGroupID(kind: kind, rootPID: 100),
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
            executablePath: name == "bun"
                ? "/Users/alex/.bun/bin/bun"
                : "/Users/alex/Documents/fluentai/node_modules/esbuild",
            workingDirectory:
                "/Users/alex/Documents/fluentai.worktrees/ds-rebuild",
            cpuPercent: cpu,
            memoryBytes: memory
        )
    }
}
