import Testing
@testable import UnhogCore

@Suite("Resource explanations")
struct ResourceExplainerTests {
    @Test("The explanation identifies the project chain and top worker")
    func explainsDeveloperStack() {
        let group = developerGroup()

        let explanation = ResourceExplainer().explain(group)

        #expect(explanation.workloadTitle == "sample-app stack")
        #expect(
            explanation.processChain
                == ["sample-app", "bun", "esbuild"]
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
                ? "/Users/example/.bun/bin/bun"
                : "/Users/example/Projects/sample-app/node_modules/esbuild",
            workingDirectory:
                "/Users/example/Projects/sample-app",
            cpuPercent: cpu,
            memoryBytes: memory
        )
    }
}
