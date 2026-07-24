import Testing
@testable import UnhogCore

@Suite("Safe termination planning")
struct TerminationPolicyTests {
    @Test("Current-user process families can be quit")
    func allowsOwnedProcesses() {
        let group = group(
            name: "Playwright",
            ownerUID: 501,
            processes: [
                process(pid: 10, parent: 1, name: "node", ownerUID: 501),
                process(pid: 11, parent: 10, name: "Chromium", ownerUID: 501)
            ]
        )

        let plan = TerminationPolicy(currentUID: 501, appPID: 999).plan(for: group)

        #expect(plan.capability == .allowed)
        #expect(plan.targets.map(\.pid) == [10, 11])
    }

    @Test("Protected system processes never produce kill targets")
    func protectsSystemProcesses() {
        let group = group(
            name: "WindowServer",
            ownerUID: 88,
            processes: [process(pid: 88, parent: 1, name: "WindowServer", ownerUID: 88)]
        )

        let plan = TerminationPolicy(currentUID: 501, appPID: 999).plan(for: group)

        #expect(plan.capability == .protected(reason: "macOS system process"))
        #expect(plan.targets.isEmpty)
    }

    @Test("The monitor cannot terminate itself")
    func protectsItself() {
        let group = group(
            name: "Unhog",
            ownerUID: 501,
            processes: [process(pid: 999, parent: 1, name: "Unhog", ownerUID: 501)]
        )

        let plan = TerminationPolicy(currentUID: 501, appPID: 999).plan(for: group)

        #expect(plan.capability == .protected(reason: "Unhog protects itself"))
        #expect(plan.targets.isEmpty)
    }

    @Test("Current-user Apple system agents remain protected")
    func protectsCurrentUserSystemAgent() {
        let finder = ProcessSample(
            identity: ProcessIdentity(pid: 700, startedAtMicroseconds: 700_000),
            parentPID: 1,
            ownerUID: 501,
            name: "Finder",
            executablePath: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder",
            cpuPercent: 10,
            memoryBytes: 100
        )
        let group = ProcessGroup(
            id: .init(kind: .application("Finder"), rootPID: 700),
            kind: .application("Finder"),
            displayName: "Finder",
            origin: nil,
            processes: [finder]
        )

        let plan = TerminationPolicy(currentUID: 501, appPID: 999).plan(for: group)

        #expect(plan.capability == .protected(reason: "macOS system process"))
        #expect(plan.targets.isEmpty)
    }

    @Test("Normal Apple GUI apps can receive a normal quit request")
    func allowsSystemApplications() {
        let safari = ProcessSample(
            identity: ProcessIdentity(pid: 701, startedAtMicroseconds: 701_000),
            parentPID: 1,
            ownerUID: 501,
            name: "Safari",
            executablePath: "/System/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 10,
            memoryBytes: 100
        )
        let group = ProcessGroup(
            id: .init(kind: .application("Safari"), rootPID: 701),
            kind: .application("Safari"),
            displayName: "Safari",
            origin: nil,
            processes: [safari]
        )

        let plan = TerminationPolicy(currentUID: 501, appPID: 999).plan(for: group)

        #expect(plan.capability == .allowed)
        #expect(plan.targets == [safari.identity])
    }

    private func process(
        pid: Int32,
        parent: Int32,
        name: String,
        ownerUID: UInt32
    ) -> ProcessSample {
        ProcessSample(
            identity: ProcessIdentity(pid: pid, startedAtMicroseconds: UInt64(pid) * 1_000),
            parentPID: parent,
            ownerUID: ownerUID,
            name: name,
            executablePath: "/bin/\(name)",
            cpuPercent: 10,
            memoryBytes: 100
        )
    }

    private func group(
        name: String,
        ownerUID: UInt32,
        processes: [ProcessSample]
    ) -> ProcessGroup {
        ProcessGroup(
            id: .init(kind: .application(name), rootPID: processes[0].identity.pid),
            kind: .application(name),
            displayName: name,
            origin: nil,
            processes: processes
        )
    }
}
