import Foundation

public struct AppVersion: Sendable, Equatable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(parsing string: String) {
        var remainder = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if remainder.hasPrefix("v") || remainder.hasPrefix("V") {
            remainder.removeFirst()
        }

        let parts = remainder.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2,
            parts.count <= 3,
            let major = Int(parts[0]),
            let minor = Int(parts[1])
        else {
            return nil
        }

        let patch = parts.count == 3 ? Int(parts[2]) ?? 0 : 0
        self.init(major: major, minor: minor, patch: patch)
    }

    public var displayString: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
