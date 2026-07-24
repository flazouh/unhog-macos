import Testing
@testable import UnhogCore

@Suite("Visual resource signatures")
struct DrainSignatureTests {
    @Test("CPU is expressed as processor cores")
    func expressesCPUAsCores() {
        let signature = DrainSignature(
            group: group(cpu: 587, memory: 1_530_000_000),
            primarySignal: .cpu,
            installedMemoryBytes: 24_000_000_000,
            logicalCoreCount: 12
        )

        #expect(signature.cpuCores == 5.87)
        #expect(signature.cpuShare == 5.87 / 12)
        #expect(signature.primarySignal == .cpu)
    }

    @Test("RAM uses installed memory as its denominator")
    func usesInstalledMemory() {
        let signature = DrainSignature(
            group: group(cpu: 18, memory: 1_440_000_000),
            primarySignal: .memory,
            installedMemoryBytes: 24_000_000_000,
            logicalCoreCount: 12
        )

        #expect(signature.memoryShare == 0.06)
        #expect(signature.primarySignal == .memory)
    }

    private func group(cpu: Double, memory: UInt64) -> ProcessGroup {
        let kind = ProcessFamilyKind.application("bun")
        let process = ProcessSample(
            identity: .init(pid: 42, startedAtMicroseconds: 42_000),
            parentPID: 1,
            ownerUID: 501,
            name: "bun",
            executablePath: "/usr/local/bin/bun",
            cpuPercent: cpu,
            memoryBytes: memory
        )
        return ProcessGroup(
            id: .init(kind: kind, rootPID: 42),
            kind: kind,
            displayName: "bun",
            origin: nil,
            processes: [process]
        )
    }
}

