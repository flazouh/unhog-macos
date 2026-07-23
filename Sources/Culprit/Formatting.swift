import Foundation

enum MetricFormatting {
    static func cpu(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func memory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: bytes),
            countStyle: .memory
        )
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds.rounded())) sec"
        }
        return "\(Int((seconds / 60).rounded())) min"
    }
}
