import Foundation
import Testing
@testable import UnhogCore

@Suite("Sustained resource pressure detection")
struct ResourcePressureDetectorTests {
    @Test("Default memory attention scales with installed RAM")
    func scalesMemoryThresholds() {
        let thresholds = ResourceThresholds.forInstalledMemory(
            24_000_000_000
        )

        #expect(thresholds.elevatedMemoryBytes == 4_800_000_000)
        #expect(thresholds.highMemoryBytes == 8_400_000_000)
    }

    @Test("Large developer stacks alert earlier than normal GUI apps")
    func treatsDeveloperMemoryAsHigherRisk() {
        var detector = ResourcePressureDetector(
            thresholds: .forInstalledMemory(24_000_000_000)
        )
        let start = Date(timeIntervalSince1970: 1_000)
        let bun = group(
            name: "bun",
            path: "/Users/example/.bun/bin/bun",
            cpu: 18,
            memory: 3_860_000_000
        )
        let chatGPT = group(
            name: "ChatGPT",
            path: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT",
            cpu: 18,
            memory: 4_200_000_000
        )

        _ = detector.evaluate([bun, chatGPT], at: start)
        let incidents = detector.evaluate(
            [bun, chatGPT],
            at: start.addingTimeInterval(20)
        )

        #expect(incidents.map(\.group.displayName) == ["bun"])
        #expect(incidents.first?.signal == .memory)
        let developerThreshold = ByteCountFormatter.string(
            fromByteCount: 3_000_000_000,
            countStyle: .memory
        )
        #expect(
            incidents.first?.reason
                == "Memory stayed above \(developerThreshold) for 20 seconds."
        )
    }

    @Test("A short compile spike does not create an incident")
    func ignoresShortSpike() {
        var detector = ResourcePressureDetector(
            thresholds: .init(
                elevatedCPUPercent: 150,
                highCPUPercent: 300,
                elevatedMemoryBytes: 1_500,
                highMemoryBytes: 3_000,
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
        var detector = ResourcePressureDetector(
            thresholds: .init(
                elevatedCPUPercent: 150,
                highCPUPercent: 300,
                elevatedMemoryBytes: 1_500,
                highMemoryBytes: 3_000,
                sustainedFor: 15
            )
        )
        let start = Date(timeIntervalSince1970: 1_000)
        let group = group(cpu: 250, memory: 900)

        _ = detector.evaluate([group], at: start)
        let incidents = detector.evaluate([group], at: start.addingTimeInterval(15))

        #expect(incidents.count == 1)
        #expect(incidents[0].severity == .elevated)
        #expect(incidents[0].signal == .cpu)
        #expect(incidents[0].reason == "CPU stayed above 150% for 15 seconds.")
    }

    @Test("Cooling down clears the pending incident")
    func clearsAfterCooling() {
        var detector = ResourcePressureDetector(thresholds: .init(sustainedFor: 10))
        let start = Date(timeIntervalSince1970: 1_000)

        _ = detector.evaluate([group(cpu: 200, memory: 900)], at: start)
        #expect(detector.evaluate([group(cpu: 20, memory: 900)], at: start.addingTimeInterval(5)).isEmpty)
        #expect(detector.evaluate([group(cpu: 200, memory: 900)], at: start.addingTimeInterval(11)).isEmpty)
    }

    @Test("Alternating CPU and memory pressure does not fake sustained pressure")
    func keepsMetricTimersSeparate() {
        var detector = ResourcePressureDetector(
            thresholds: .init(
                elevatedCPUPercent: 150,
                highCPUPercent: 300,
                elevatedMemoryBytes: 1_500,
                highMemoryBytes: 3_000,
                sustainedFor: 15
            )
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(detector.evaluate([group(cpu: 200, memory: 900)], at: start).isEmpty)
        #expect(detector.evaluate([group(cpu: 20, memory: 2_000)], at: start.addingTimeInterval(8)).isEmpty)
        #expect(detector.evaluate([group(cpu: 200, memory: 900)], at: start.addingTimeInterval(16)).isEmpty)
    }

    private func group(
        name: String = "Playwright",
        path: String = "/playwright",
        cpu: Double,
        memory: UInt64
    ) -> ProcessGroup {
        let process = ProcessSample(
            identity: ProcessIdentity(pid: 42, startedAtMicroseconds: 42_000),
            parentPID: 1,
            ownerUID: 501,
            name: name,
            executablePath: path,
            cpuPercent: cpu,
            memoryBytes: memory
        )
        return ProcessGroup(
            id: .init(kind: .application(name), rootPID: 42),
            kind: .application(name),
            displayName: name,
            origin: nil,
            processes: [process]
        )
    }
}
