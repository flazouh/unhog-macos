import Testing
@testable import UnhogCore

@Suite("Known developer tool icons")
struct KnownToolIconResolverTests {
    @Test("Bun command-line workloads resolve to the bundled Bun mark")
    func resolvesBun() {
        #expect(
            KnownToolIconResolver.icon(
                for: group(
                    kind: .application("bun"),
                    name: "bun",
                    path: "/Users/alex/.bun/bin/bun"
                )
            ) == .bun
        )
    }

    @Test("Special developer families use their own marks")
    func resolvesSpecialFamilies() {
        #expect(
            KnownToolIconResolver.icon(
                for: group(kind: .nx, name: "node", path: "/usr/bin/node")
            ) == .nx
        )
        #expect(
            KnownToolIconResolver.icon(
                for: group(
                    kind: .typeScript,
                    name: "tsserver",
                    path: "/usr/bin/node"
                )
            ) == .typeScript
        )
        #expect(
            KnownToolIconResolver.icon(
                for: group(
                    kind: .playwright,
                    name: "node",
                    path: "/usr/bin/node"
                )
            ) == .playwright
        )
    }

    @Test("Node CLI resolves without replacing normal application icons")
    func resolvesNodeButNotGUIApps() {
        #expect(
            KnownToolIconResolver.icon(
                for: group(
                    kind: .application("node"),
                    name: "node",
                    path: "/opt/homebrew/bin/node"
                )
            ) == .node
        )
        #expect(
            KnownToolIconResolver.icon(
                for: group(
                    kind: .application("Cursor"),
                    name: "Cursor",
                    path: "/Applications/Cursor.app/Contents/MacOS/Cursor"
                )
            ) == nil
        )
        #expect(
            KnownToolIconResolver.icon(
                for: group(
                    kind: .application("Node"),
                    name: "node",
                    path: "/Applications/Node.app/Contents/MacOS/node"
                )
            ) == nil
        )
    }

    private func group(
        kind: ProcessFamilyKind,
        name: String,
        path: String
    ) -> ProcessGroup {
        ProcessGroup(
            id: ProcessGroupID(kind: kind, rootPID: 100),
            kind: kind,
            displayName: kind.displayName,
            origin: nil,
            processes: [
                ProcessSample(
                    identity: ProcessIdentity(
                        pid: 100,
                        startedAtMicroseconds: 1_000
                    ),
                    parentPID: 1,
                    ownerUID: 501,
                    name: name,
                    executablePath: path,
                    workingDirectory: "/Users/alex/Documents/fluentai",
                    cpuPercent: 50,
                    memoryBytes: 500_000_000
                )
            ]
        )
    }
}
