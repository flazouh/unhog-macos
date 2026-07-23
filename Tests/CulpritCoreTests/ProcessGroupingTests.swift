import Testing
@testable import CulpritCore

@Suite("Process family grouping")
struct ProcessGroupingTests {
    @Test("Playwright helpers are grouped as one culprit")
    func groupsPlaywrightHelpers() {
        let samples = [
            sample(pid: 100, parent: 1, name: "Claude", path: "/Applications/Claude.app/Claude", cpu: 3, memory: 100),
            sample(pid: 110, parent: 100, name: "bun", path: "/Users/alex/.bun/bin/bun", cpu: 7, memory: 80),
            sample(pid: 120, parent: 110, name: "chromium_headless_shell", path: "/Users/alex/Library/Caches/ms-playwright/chromium_headless_shell", cpu: 180, memory: 300),
            sample(pid: 121, parent: 120, name: "Chromium Helper (GPU)", path: "/Users/alex/Library/Caches/ms-playwright/Chromium Helper", cpu: 130, memory: 400)
        ]

        let groups = ProcessGrouper().groups(from: samples)
        let playwright = groups.first { $0.kind == .playwright }

        #expect(playwright?.displayName == "Playwright")
        #expect(playwright?.processes.map(\.identity.pid).sorted() == [120, 121])
        #expect(playwright?.cpuPercent == 310)
        #expect(playwright?.memoryBytes == 700)
        #expect(playwright?.origin == "Started by bun")
    }

    @Test("Sibling TypeScript servers remain separate kill targets")
    func separatesTypeScriptServers() {
        let samples = [
            sample(pid: 200, parent: 1, name: "Code", path: "/Applications/Visual Studio Code.app/Code", cpu: 2, memory: 100),
            sample(pid: 201, parent: 200, name: "tsserver", path: "/node_modules/typescript/lib/tsserver.js", cpu: 80, memory: 600),
            sample(pid: 202, parent: 200, name: "typescript-language-server", path: "/bin/typescript-language-server", cpu: 40, memory: 500)
        ]

        let groups = ProcessGrouper().groups(from: samples)
        let typescript = groups.filter { $0.kind == .typeScript }

        #expect(typescript.count == 2)
        #expect(typescript.allSatisfy { $0.displayName == "TypeScript servers" })
        #expect(typescript.allSatisfy { $0.processes.count == 1 })
        #expect(typescript.reduce(0) { $0 + $1.memoryBytes } == 1_100)
    }

    @Test("Tagged sibling launchers remain separate kill targets")
    func separatesTaggedSiblingLaunchers() {
        let samples = [
            sample(pid: 100, parent: 1, name: "Claude", path: "/Applications/Claude.app/Claude", cpu: 1, memory: 10),
            sample(pid: 110, parent: 100, name: "bun", path: "/Users/alex/.bun/bin/bun", cpu: 5, memory: 20, tags: [.playwright]),
            sample(pid: 120, parent: 110, name: "chromium_headless_shell", path: "/Caches/ms-playwright/chromium_headless_shell", cpu: 100, memory: 200),
            sample(pid: 210, parent: 100, name: "bun", path: "/Users/alex/.bun/bin/bun", cpu: 7, memory: 30, tags: [.playwright]),
            sample(pid: 220, parent: 210, name: "chromium_headless_shell", path: "/Caches/ms-playwright/chromium_headless_shell", cpu: 120, memory: 300)
        ]

        let playwright = ProcessGrouper()
            .groups(from: samples)
            .filter { $0.kind == .playwright }

        #expect(playwright.count == 2)
        #expect(Set(playwright.map(\.id.rootPID)) == [110, 210])
        #expect(playwright.map { $0.processes.map(\.identity.pid) }.contains([110, 120]))
        #expect(playwright.map { $0.processes.map(\.identity.pid) }.contains([210, 220]))
    }

    @Test("Unrelated Playwright sessions are separate kill targets")
    func separatesPlaywrightSessions() {
        let samples = [
            sample(pid: 100, parent: 1, name: "Claude", path: "/Applications/Claude.app/Claude", cpu: 1, memory: 10),
            sample(pid: 110, parent: 100, name: "bun", path: "/Users/alex/.bun/bin/bun", cpu: 1, memory: 10),
            sample(pid: 120, parent: 110, name: "chromium_headless_shell", path: "/Caches/ms-playwright/chromium_headless_shell", cpu: 100, memory: 200),
            sample(pid: 200, parent: 1, name: "Terminal", path: "/System/Applications/Utilities/Terminal.app/Terminal", cpu: 1, memory: 10),
            sample(pid: 210, parent: 200, name: "node", path: "/opt/homebrew/bin/node", cpu: 1, memory: 10),
            sample(pid: 220, parent: 210, name: "chromium_headless_shell", path: "/Caches/ms-playwright/chromium_headless_shell", cpu: 120, memory: 300)
        ]

        let playwright = ProcessGrouper()
            .groups(from: samples)
            .filter { $0.kind == .playwright }

        #expect(playwright.count == 2)
        #expect(playwright.map { $0.processes.map(\.identity.pid) }.contains([120]))
        #expect(playwright.map { $0.processes.map(\.identity.pid) }.contains([220]))
        #expect(Set(playwright.compactMap(\.origin)) == ["Started by bun", "Started by node"])
    }

    @Test("Ordinary descendants stay under their top-level application")
    func groupsOrdinaryApplicationTree() {
        let samples = [
            sample(pid: 300, parent: 1, name: "Arc", path: "/Applications/Arc.app/Arc", cpu: 20, memory: 200),
            sample(pid: 301, parent: 300, name: "Arc Helper", path: "/Applications/Arc.app/Arc Helper", cpu: 40, memory: 300)
        ]

        let groups = ProcessGrouper().groups(from: samples)
        let arc = groups.first { $0.displayName == "Arc" }

        #expect(arc?.processes.count == 2)
        #expect(arc?.cpuPercent == 60)
        #expect(arc?.memoryBytes == 500)
    }

    private func sample(
        pid: Int32,
        parent: Int32,
        name: String,
        path: String,
        cpu: Double,
        memory: UInt64,
        tags: Set<ProcessTag> = []
    ) -> ProcessSample {
        ProcessSample(
            identity: ProcessIdentity(pid: pid, startedAtMicroseconds: UInt64(pid) * 1_000),
            parentPID: parent,
            ownerUID: 501,
            name: name,
            executablePath: path,
            cpuPercent: cpu,
            memoryBytes: memory,
            tags: tags
        )
    }
}
