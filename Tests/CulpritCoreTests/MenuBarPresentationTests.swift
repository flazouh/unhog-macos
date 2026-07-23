import Foundation
import Testing
@testable import CulpritCore

@Suite("Adaptive menu bar presentation")
struct MenuBarPresentationTests {
    @Test("Calm adaptive mode stays icon only")
    func calmIsQuiet() {
        let presentation = MenuBarPresentation.make(
            phase: .calm,
            leadingGroup: nil,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .adaptive
        )

        #expect(presentation.symbolName == "circle")
        #expect(presentation.compactLabel == nil)
        #expect(presentation.accessibilityLabel == "Unhog. No unusual resource drain.")
    }

    @Test("CPU incident explains processor cores")
    func explainsCPUIncident() {
        let incident = incident(signal: .cpu, cpu: 587, memory: 1_530_000_000)

        let presentation = MenuBarPresentation.make(
            phase: .attention(incident),
            leadingGroup: incident.group,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .adaptive
        )

        #expect(presentation.symbolName == "exclamationmark.circle")
        #expect(presentation.compactLabel == "5.9c")
        #expect(
            presentation.accessibilityLabel
                == "Unhog. bun needs attention and is using about 5.9 processor cores."
        )
    }

    @Test("Memory incident uses installed RAM as its denominator")
    func explainsMemoryIncident() {
        let incident = incident(signal: .memory, cpu: 18, memory: 1_530_000_000)

        let presentation = MenuBarPresentation.make(
            phase: .attention(incident),
            leadingGroup: incident.group,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .adaptive
        )

        #expect(presentation.compactLabel == "6%")
        #expect(
            presentation.accessibilityLabel
                == "Unhog. bun needs attention and is using 6% of installed memory."
        )
    }

    @Test("Verified recovery briefly shows measured memory reclaimed")
    func explainsRecovery() {
        let original = group(cpu: 184, memory: 3_860_000_000)
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

        let presentation = MenuBarPresentation.make(
            phase: .recovered(receipt),
            leadingGroup: nil,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .adaptive
        )

        #expect(presentation.symbolName == "checkmark.circle")
        #expect(presentation.compactLabel == "3.9 GB")
        #expect(
            presentation.accessibilityLabel
                == "Unhog. Resource use recovered. Workload memory fell by 3.9 gigabytes."
        )
    }

    @Test("Icon only mode never adds compact text")
    func honorsIconOnlyMode() {
        let incident = incident(signal: .cpu, cpu: 587, memory: 1_530_000_000)

        let presentation = MenuBarPresentation.make(
            phase: .attention(incident),
            leadingGroup: incident.group,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .iconOnly
        )

        #expect(presentation.compactLabel == nil)
    }

    @Test("Always-visible CPU mode speaks the visible workload metric")
    func speaksAlwaysVisibleCPU() {
        let group = group(cpu: 587, memory: 1_530_000_000)

        let presentation = MenuBarPresentation.make(
            phase: .calm,
            leadingGroup: group,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .topCPU
        )

        #expect(presentation.compactLabel == "5.9c")
        #expect(
            presentation.accessibilityLabel
                == "Unhog. No unusual resource drain. Top workload bun is using about 5.9 processor cores."
        )
    }

    @Test("Restarted state shows the successor's current primary metric")
    func explainsRestartedWorkload() {
        let original = group(cpu: 184, memory: 3_860_000_000)
        let successor = group(
            pid: 84,
            cpu: 220,
            memory: 1_200_000_000
        )
        let assessment = RecoveryVerifier().assess(
            original: original,
            currentGroups: [successor],
            currentProcessIdentities: Set(
                successor.processes.map(\.identity)
            ),
            verificationDuration: 2
        )
        guard case let .restarted(receipt) = assessment else {
            Issue.record("Expected a restarted receipt")
            return
        }

        let presentation = MenuBarPresentation.make(
            phase: .restarted(receipt),
            leadingGroup: successor,
            installedMemoryBytes: 24_000_000_000,
            displayMode: .adaptive
        )

        #expect(presentation.compactLabel == "2.2c")
    }

    private func incident(
        signal: ResourceSignal,
        cpu: Double,
        memory: UInt64
    ) -> ResourceIncident {
        let group = group(cpu: cpu, memory: memory)
        return ResourceIncident(
            id: group.id,
            group: group,
            severity: .elevated,
            signal: signal,
            beganAt: Date(timeIntervalSince1970: 1_000),
            duration: 20,
            reason: "Sustained resource drain."
        )
    }

    private func group(
        pid: Int32 = 42,
        cpu: Double,
        memory: UInt64
    ) -> ProcessGroup {
        let process = ProcessSample(
            identity: .init(
                pid: pid,
                startedAtMicroseconds: UInt64(pid) * 1_000
            ),
            parentPID: 1,
            ownerUID: 501,
            name: "bun",
            executablePath: "/Users/example/.bun/bin/bun",
            cpuPercent: cpu,
            memoryBytes: memory
        )
        let kind = ProcessFamilyKind.application("bun")
        return ProcessGroup(
            id: .init(kind: kind, rootPID: pid),
            kind: kind,
            displayName: "bun",
            origin: nil,
            processes: [process]
        )
    }
}
