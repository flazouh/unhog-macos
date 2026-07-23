import Testing
@testable import CulpritCore

@Suite("Resource snapshot presentation")
struct ResourceSnapshotTests {
    @Test("Memory shares use installed RAM as the single scale")
    func mapsGroupsIntoInstalledMemory() {
        let composition = MemoryComposition(
            installedBytes: 1_000,
            groups: [
                group(pid: 10, name: "bun", cpu: 18, memory: 250),
                group(pid: 20, name: "Cursor", cpu: 46, memory: 100)
            ]
        )

        #expect(composition.segments.map(\.shareOfInstalledRAM) == [0.25, 0.10])
        #expect(composition.attributedBytes == 350)
        #expect(composition.remainderBytes == 650)
        #expect(composition.remainderShare == 0.65)
    }

    @Test("The current issue stays visible in a compact memory map")
    func keepsPrioritizedGroupVisible() {
        let focused = group(
            pid: 40,
            name: "CPU-heavy",
            cpu: 400,
            memory: 10
        )
        let composition = MemoryComposition(
            installedBytes: 1_000,
            groups: [
                group(pid: 10, name: "A", cpu: 1, memory: 300),
                group(pid: 20, name: "B", cpu: 1, memory: 200),
                group(pid: 30, name: "C", cpu: 1, memory: 100),
                focused
            ],
            maximumVisibleSegments: 3,
            prioritizedGroupID: focused.id
        )

        #expect(composition.segments.map(\.id).contains(focused.id))
        #expect(composition.segments.first?.id == focused.id)
    }

    @Test("Battery impact is a coarse CPU-derived estimate")
    func estimatesBatteryImpact() {
        #expect(BatteryDrainEstimate(cpuPercent: 4) == .low)
        #expect(BatteryDrainEstimate(cpuPercent: 42) == .elevated)
        #expect(BatteryDrainEstimate(cpuPercent: 120) == .high)
    }

    @Test("Imperfect process totals never overflow the RAM bar")
    func clampsMemoryMapToOneHundredPercent() {
        let composition = MemoryComposition(
            installedBytes: 100,
            groups: [
                group(pid: 10, name: "A", cpu: 1, memory: 80),
                group(pid: 20, name: "B", cpu: 1, memory: 50)
            ]
        )

        #expect(composition.segments.map(\.shareOfInstalledRAM) == [0.8])
        #expect(composition.segments.map(\.bytes) == [80])
        #expect(composition.remainderShare == 0.2)
        #expect(composition.hasOverlappingProcessTotals)
    }

    private func group(
        pid: Int32,
        name: String,
        cpu: Double,
        memory: UInt64
    ) -> ProcessGroup {
        let kind = ProcessFamilyKind.application(name)
        return ProcessGroup(
            id: ProcessGroupID(kind: kind, rootPID: pid),
            kind: kind,
            displayName: name,
            origin: nil,
            processes: [
                ProcessSample(
                    identity: ProcessIdentity(
                        pid: pid,
                        startedAtMicroseconds: UInt64(pid) * 1_000
                    ),
                    parentPID: 1,
                    ownerUID: 501,
                    name: name,
                    executablePath: "/Applications/\(name).app/\(name)",
                    cpuPercent: cpu,
                    memoryBytes: memory
                )
            ]
        )
    }
}
