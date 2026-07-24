import Foundation

public enum KnownToolIcon: String, Hashable, Sendable {
    case bun
    case node
    case nx
    case playwright
    case typeScript

    public var bundledAssetName: String? {
        switch self {
        case .bun: "bun"
        case .node: "node"
        case .nx: "nx"
        case .typeScript: "typescript"
        case .playwright: nil
        }
    }
}

public enum KnownToolIconResolver {
    public static func icon(for group: ProcessGroup) -> KnownToolIcon? {
        switch group.kind {
        case .playwright:
            return .playwright
        case .typeScript:
            return .typeScript
        case .nx:
            return .nx
        case .application:
            break
        }

        let root = group.processes.first {
            $0.identity.pid == group.id.rootPID
        } ?? group.processes.first
        let executableName = root.map {
            ($0.executablePath as NSString).lastPathComponent.lowercased()
        }

        guard root?.executablePath.contains(".app/") != true else {
            return nil
        }
        if executableName == "bun" || executableName == "bunx" {
            return .bun
        }
        if executableName == "node" || executableName == "nodejs" {
            return .node
        }
        return nil
    }
}
