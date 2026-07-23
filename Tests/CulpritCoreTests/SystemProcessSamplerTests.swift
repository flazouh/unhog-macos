import Darwin
import Testing
@testable import CulpritCore

@Suite("System process sampler")
struct SystemProcessSamplerTests {
    @Test("Sampling returns the current process with finite metrics")
    func samplesCurrentProcess() async throws {
        let monitor = ProcessMonitor()
        _ = await monitor.sample()
        try await Task.sleep(for: .milliseconds(50))
        let samples = await monitor.sample()

        let current = samples.first { $0.identity.pid == getpid() }

        #expect(current != nil)
        #expect(current?.cpuPercent.isFinite == true)
        #expect((current?.memoryBytes ?? 0) > 0)
    }
}
