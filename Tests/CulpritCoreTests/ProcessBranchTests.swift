import Testing
@testable import CulpritCore

@Suite("Process-tree branches")
struct ProcessBranchTests {
    @Test("A branch contains its root and descendants, not siblings or ancestors")
    func resolvesDescendantsOnly() throws {
        let group = workload()
        let chromium = try #require(
            group.processes.first { $0.name == "Chromium" }
        )

        let branch = try #require(
            ProcessBranchResolver().branch(
                rootedAt: chromium.identity,
                in: group
            )
        )

        #expect(branch.processes.map(\.name) == ["Chromium", "GPU"])
        #expect(!branch.processes.contains { $0.name == "Playwright" })
        #expect(!branch.processes.contains { $0.name == "Trace viewer" })
    }

    @Test("Visible branches are the workload root's direct children")
    func exposesMainBranches() {
        let branches = ProcessBranchResolver().visibleBranches(
            in: workload()
        )

        #expect(branches.map(\.displayName) == ["Chromium", "Trace viewer"])
    }

    @Test("Termination asks descendants to stop before their branch root")
    func terminatesDeepestFirst() throws {
        let group = workload()
        let chromium = try #require(
            group.processes.first { $0.name == "Chromium" }
        )
        let branch = try #require(
            ProcessBranchResolver().branch(
                rootedAt: chromium.identity,
                in: group
            )
        )

        let plan = TerminationPolicy(
            currentUID: 501,
            appPID: 999
        ).plan(for: branch)

        #expect(plan.capability == .allowed)
        #expect(plan.targets.map(\.pid) == [102, 101])
    }

    @Test("A malformed cycle cannot pull the workload root or siblings into a branch")
    func malformedCycleStaysInsideSelectedBranch() throws {
        let root = sample(pid: 10, parent: 20, name: "runner")
        let selected = sample(pid: 20, parent: 10, name: "chromium")
        let helper = sample(pid: 21, parent: 20, name: "helper")
        let sibling = sample(pid: 30, parent: 10, name: "trace")
        let group = makeGroup([root, selected, helper, sibling])

        let branch = try #require(
            ProcessBranchResolver().branch(
                rootedAt: selected.identity,
                in: group
            )
        )

        #expect(Set(branch.processes.map(\.identity.pid)) == [20, 21])
    }

    @Test("A small single-process top worker remains visible")
    func topWorkerException() {
        let root = sample(pid: 10, parent: 1, name: "runner")
        let worker = ProcessSample(
            identity: .init(pid: 20, startedAtMicroseconds: 20_000),
            parentPID: 10,
            ownerUID: 501,
            name: "compiler",
            executablePath: "/usr/bin/compiler",
            cpuPercent: 250,
            memoryBytes: 10_000_000
        )
        let sibling = sample(pid: 30, parent: 10, name: "trace")
        let group = makeGroup([root, worker, sibling])

        let visible = ProcessBranchResolver().visibleBranches(in: group)

        #expect(visible.contains { $0.root.identity == worker.identity })
    }

    private func workload() -> ProcessGroup {
        let samples = [
            sample(pid: 100, parent: 1, name: "Playwright", memory: 100),
            sample(pid: 101, parent: 100, name: "Chromium", memory: 900),
            sample(pid: 102, parent: 101, name: "GPU", memory: 300),
            sample(
                pid: 103,
                parent: 100,
                name: "Trace viewer",
                memory: 220_000_000
            )
        ]
        return makeGroup(samples)
    }

    private func makeGroup(
        _ samples: [ProcessSample]
    ) -> ProcessGroup {
        let kind = ProcessFamilyKind.playwright
        return ProcessGroup(
            id: .init(kind: kind, rootPID: samples[0].identity.pid),
            kind: kind,
            displayName: "Playwright",
            origin: nil,
            processes: samples
        )
    }

    private func sample(
        pid: Int32,
        parent: Int32,
        name: String,
        memory: UInt64 = 1_000_000
    ) -> ProcessSample {
        ProcessSample(
            identity: .init(
                pid: pid,
                startedAtMicroseconds: UInt64(pid) * 1_000
            ),
            parentPID: parent,
            ownerUID: 501,
            name: name,
            executablePath: "/tools/\(name)",
            cpuPercent: 10,
            memoryBytes: memory
        )
    }
}
