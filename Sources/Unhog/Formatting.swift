import UnhogCore
import Foundation

enum MetricFormatting {
    static func cpu(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func memory(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 KB" }
        return ByteCountFormatter.string(
            fromByteCount: Int64(clamping: bytes),
            countStyle: .memory
        )
    }

    static func storage(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 KB" }
        return ByteCountFormatter.string(
            fromByteCount: Int64(clamping: bytes),
            countStyle: .file
        )
    }

    static func ramShare(_ share: Double) -> String {
        let percent = max(0, min(1, share)) * 100
        if percent > 0, percent < 1 {
            return "<1%"
        }
        return "\(Int(percent.rounded()))%"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds.rounded())) sec"
        }
        return "\(Int((seconds / 60).rounded())) min"
    }
}

enum WorkloadPresentation {
    static func shortName(
        for group: ProcessGroup,
        includesProjectName: Bool = true
    ) -> String {
        (includesProjectName ? group.contextLabel : nil)?
            .components(separatedBy: " · ").first
            ?? group.displayName
    }

    static func actionTitle(
        for group: ProcessGroup,
        includesProjectName: Bool = true
    ) -> String {
        let root =
            group.processes.first {
                $0.identity.pid == group.id.rootPID
            } ?? group.processes.first
        if root?.executablePath.contains(".app/") == true {
            return "Quit \(group.displayName)"
        }
        if includesProjectName, group.contextLabel != nil {
            return "Stop \(shortName(for: group)) stack"
        }
        return "Stop \(group.displayName) group"
    }
}
