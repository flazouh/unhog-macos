import Foundation
import Testing
@testable import CulpritCore

@Suite("Sustained heat detection")
struct HeatDetectorTests {
    @Test("A short compile spike does not create an incident")
    func ignoresShortSpike() {
        var detector = HeatDetector(
            thresholds: .init(
                warningCPUPercent: 150,
                criticalCPUPercent: 300,
                warningMemoryBytes: 1_500,
                criticalMemoryBytes: 3_000,
                sustainedFor: 15
            )
        )
        let start = Date(timeIntervalSince1970: 1_000)
        let group = group(cpu: 250, memory: 900)

        #expect(detector.evaluate([group], at: start).isEmpty)
        #expect(detector.evaluate([group], at: start.addingTimeInterval(14)).isEmpty)
    }

    @Test("Sustained pressure creates an explainable incident")
    func reportsSustainedPressure() {
        var detector = HeatDetector(
            thresholds: .init(
                warningCPUPercent: 150,
                criticalCPUPercent: 300,
                warningMemoryBytes: 1_500,
                criticalMemoryBytes: 3_000,
                sustainedFor: 15
            )
        )
        let start = Date(timeIntervalSince1970: 1_000)
        let group = group(cpu: 250, memory: 900)

        _ = detector.evaluate([group], at: start)
        let incidents = detector.evaluate([group], at: start.addingTimeInterval(15))

        #expect(incidents.count == 1)
        #expect(incidents[0].severity == .warning)
        #expect(incidents[0].reason == "CPU stayed above 150% for 15 seconds.")
    }

    @Test("Cooling down clears the pending incident")
    func clearsAfterCooling() {
        var detector = HeatDetector(thresholds: .init(sustainedFor: 10))
        let start = Date(timeIntervalSince1970: 1_000)

        _ = detector.evaluate([group(cpu: 200, memory: 900)], at: start)
        #expect(detector.evaluate([group(cpu: 20, memory: 900)], at: start.addingTimeInterval(5)).isEmpty)
        #expect(detector.evaluate([group(cpu: 200, memory: 900)], at: start.addingTimeInterval(11)).isEmpty)
    }

    @Test("Alternating CPU and memory pressure does not fake sustained pressure")
    func keepsMetricTimersSeparate() {
        var detector = HeatDetector(
            thresholds: .init(
                warningCPUPercent: 150,
                criticalCPUPercent: 300,
                warningMemoryBytes: 1_500,
                criticalMemoryBytes: 3_000,
                sustainedFor: 15
            )
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(detector.evaluate([group(cpu: 200, memory: 900)], at: start).isEmpty)
        #expect(detector.evaluate([group(cpu: 20, memory: 2_000)], at: start.addingTimeInterval(8)).isEmpty)
        #expect(detector.evaluate([group(cpu: 200, memory: 900)], at: start.addingTimeInterval(16)).isEmpty)
    }

    private func group(cpu: Double, memory: UInt64) -> ProcessGroup {
        let process = ProcessSample(
            identity: ProcessIdentity(pid: 42, startedAtMicroseconds: 42_000),
            parentPID: 1,
            ownerUID: 501,
            name: "Playwright",
            executablePath: "/playwright",
            cpuPercent: cpu,
            memoryBytes: memory
        )
        return ProcessGroup(
            id: .init(kind: .playwright, rootPID: 42),
            kind: .playwright,
            displayName: "Playwright",
            origin: nil,
            processes: [process]
        )
    }
}
