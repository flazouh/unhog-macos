import Darwin
import Foundation

public actor ProcessMonitor {
    private let sampler = SystemProcessSampler()

    public init() {}

    public func sample() -> [ProcessSample] {
        sampler.sample()
    }
}

final class SystemProcessSampler {
    private struct Metadata {
        let parentPID: Int32
        let ownerUID: UInt32
        let name: String
        let path: String
        let workingDirectory: String?
        let tags: Set<ProcessTag>
    }

    private var previousCPUTime: [ProcessIdentity: UInt64] = [:]
    private var previousWallTimeNanoseconds: UInt64?
    private var metadataCache: [ProcessIdentity: Metadata] = [:]

    private static let timebase: mach_timebase_info_data_t = {
        var value = mach_timebase_info_data_t()
        mach_timebase_info(&value)
        return value
    }()

    func sample() -> [ProcessSample] {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = previousWallTimeNanoseconds.map { Double(now &- $0) } ?? 0
        var nextCPUTime: [ProcessIdentity: UInt64] = [:]
        var samples: [ProcessSample] = []

        for pid in Self.allPIDs() where pid > 0 {
            guard let allInfo = Self.taskAllInfo(for: pid) else {
                continue
            }
            let bsd = allInfo.pbsd
            let task = allInfo.ptinfo

            let identity = ProcessIdentity(
                pid: pid,
                startedAtMicroseconds: bsd.pbi_start_tvsec * 1_000_000 + bsd.pbi_start_tvusec
            )
            let ticks = task.pti_total_user &+ task.pti_total_system
            let cpuNanoseconds = Self.nanoseconds(fromMachTicks: ticks)
            nextCPUTime[identity] = cpuNanoseconds

            let cpuPercent: Double
            if let previous = previousCPUTime[identity],
                elapsed > 0,
                cpuNanoseconds >= previous
            {
                cpuPercent = Double(cpuNanoseconds - previous) / elapsed * 100
            } else {
                cpuPercent = 0
            }

            let metadata: Metadata
            if let cached = metadataCache[identity] {
                metadata = cached
            } else {
                let name = Self.name(for: pid)
                let path = Self.path(for: pid)
                metadata = Metadata(
                    parentPID: Int32(bitPattern: bsd.pbi_ppid),
                    ownerUID: bsd.pbi_uid,
                    name: name,
                    path: path,
                    workingDirectory: Self.workingDirectory(for: pid),
                    tags: Self.tags(for: pid, name: name, path: path)
                )
            }
            metadataCache[identity] = metadata

            samples.append(
                ProcessSample(
                    identity: identity,
                    parentPID: metadata.parentPID,
                    ownerUID: metadata.ownerUID,
                    name: metadata.name,
                    executablePath: metadata.path,
                    workingDirectory: metadata.workingDirectory,
                    cpuPercent: cpuPercent.isFinite ? max(0, cpuPercent) : 0,
                    memoryBytes: Self.memoryBytes(
                        for: pid,
                        ownerUID: bsd.pbi_uid,
                        residentBytes: task.pti_resident_size,
                        cpuPercent: cpuPercent
                    ),
                    tags: metadata.tags
                )
            )
        }

        previousCPUTime = nextCPUTime
        previousWallTimeNanoseconds = now
        let living = Set(nextCPUTime.keys)
        metadataCache = metadataCache.filter { living.contains($0.key) }
        return samples
    }

    private static func allPIDs() -> [Int32] {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(estimatedCount) + 64)
        let count = proc_listallpids(
            &pids,
            Int32(pids.count * MemoryLayout<Int32>.size)
        )
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count)))
    }

    private static func taskAllInfo(for pid: Int32) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let size = Int32(MemoryLayout<proc_taskallinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size)
        return result == size ? info : nil
    }

    private static func physicalFootprint(for pid: Int32) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutableBytes(of: &info) { rawBuffer -> Int32 in
            guard let baseAddress = rawBuffer.baseAddress else { return -1 }
            let buffer = baseAddress.assumingMemoryBound(to: rusage_info_t?.self)
            return proc_pid_rusage(pid, RUSAGE_INFO_V4, buffer)
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }

    private static func memoryBytes(
        for pid: Int32,
        ownerUID: UInt32,
        residentBytes: UInt64,
        cpuPercent: Double
    ) -> UInt64 {
        let warrantsPreciseMeasurement =
            residentBytes >= 30_000_000 || cpuPercent >= 1
        guard ownerUID == getuid(), warrantsPreciseMeasurement else {
            return residentBytes
        }
        return physicalFootprint(for: pid) ?? residentBytes
    }

    private static func name(for pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? decode(buffer, count: Int(length)) : "Process \(pid)"
    }

    private static func path(for pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 4_096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? decode(buffer, count: Int(length)) : ""
    }

    private static func workingDirectory(for pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size)
        guard result == size else { return nil }

        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: Int(MAXPATHLEN)
            ) {
                String(cString: $0)
            }
        }
        return path.isEmpty ? nil : path
    }

    private static func decode(_ buffer: [CChar], count: Int) -> String {
        String(
            decoding: buffer.prefix(count).map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }

    private static func nanoseconds(fromMachTicks ticks: UInt64) -> UInt64 {
        let numerator = UInt64(timebase.numer)
        let denominator = UInt64(timebase.denom)
        let quotient = ticks / denominator
        let remainder = ticks % denominator
        return quotient &* numerator &+ remainder &* numerator / denominator
    }

    private static func tags(
        for pid: Int32,
        name: String,
        path: String
    ) -> Set<ProcessTag> {
        let basic = "\(name) \(path)".lowercased()
        let basename = (path as NSString).lastPathComponent.lowercased()
        let shouldInspectArguments =
            [
                "node",
                "bun",
                "nx",
                "tsserver",
                "typescript-language-server",
            ].contains(basename) || basic.contains("tsserver")

        let arguments: [String]
        if shouldInspectArguments,
            let parsedArguments = processArguments(for: pid)
        {
            arguments = parsedArguments
        } else {
            arguments = []
        }

        return ProcessClassifier.tags(
            name: name,
            path: path,
            arguments: arguments
        )
    }

    private static func processArguments(for pid: Int32) -> [String]? {
        var maximumLength: Int32 = 0
        var maximumLengthSize = MemoryLayout<Int32>.size
        var maximumLengthQuery = [CTL_KERN, KERN_ARGMAX]
        guard
            sysctl(
                &maximumLengthQuery,
                2,
                &maximumLength,
                &maximumLengthSize,
                nil,
                0
            ) == 0, maximumLength > 0
        else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: Int(maximumLength))
        var bufferSize = buffer.count
        var query = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&query, 3, &buffer, &bufferSize, nil, 0) == 0,
            bufferSize > MemoryLayout<Int32>.size
        else {
            return nil
        }

        var argumentCount: Int32 = 0
        memcpy(&argumentCount, buffer, MemoryLayout<Int32>.size)
        guard argumentCount > 0 else { return nil }

        var cursor = MemoryLayout<Int32>.size
        while cursor < bufferSize, buffer[cursor] != 0 { cursor += 1 }
        while cursor < bufferSize, buffer[cursor] == 0 { cursor += 1 }

        var arguments: [String] = []
        while arguments.count < Int(argumentCount), cursor < bufferSize {
            let start = cursor
            while cursor < bufferSize, buffer[cursor] != 0 { cursor += 1 }
            let value = String(
                decoding: buffer[start..<cursor].map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
            if !value.isEmpty {
                arguments.append(value)
            }
            cursor += 1
        }
        return arguments.isEmpty ? nil : arguments
    }
}
