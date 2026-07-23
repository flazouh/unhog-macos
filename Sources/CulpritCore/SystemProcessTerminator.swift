import Darwin
import Foundation

public enum TerminationMode: Sendable {
    case graceful
    case force
}

public struct TerminationFailure: Hashable, Sendable {
    public let identity: ProcessIdentity
    public let message: String

    public init(identity: ProcessIdentity, message: String) {
        self.identity = identity
        self.message = message
    }
}

public struct TerminationResult: Hashable, Sendable {
    public let signalled: [ProcessIdentity]
    public let alreadyStopped: [ProcessIdentity]
    public let failures: [TerminationFailure]

    public init(
        signalled: [ProcessIdentity],
        alreadyStopped: [ProcessIdentity],
        failures: [TerminationFailure]
    ) {
        self.signalled = signalled
        self.alreadyStopped = alreadyStopped
        self.failures = failures
    }
}

public actor SystemProcessTerminator {
    private let currentUID: UInt32

    public init(currentUID: UInt32) {
        self.currentUID = currentUID
    }

    public func terminate(
        _ plan: TerminationPlan,
        mode: TerminationMode
    ) -> TerminationResult {
        guard plan.capability == .allowed else {
            return TerminationResult(
                signalled: [],
                alreadyStopped: [],
                failures: plan.targets.map {
                    TerminationFailure(identity: $0, message: "Protected process")
                }
            )
        }

        let signal = mode == .graceful ? SIGTERM : SIGKILL
        var signalled: [ProcessIdentity] = []
        var alreadyStopped: [ProcessIdentity] = []
        var failures: [TerminationFailure] = []

        for identity in plan.targets {
            guard let current = Self.identityAndOwner(for: identity.pid) else {
                alreadyStopped.append(identity)
                continue
            }

            guard current.identity == identity else {
                failures.append(
                    TerminationFailure(
                        identity: identity,
                        message: "PID was reused by another process"
                    )
                )
                continue
            }

            guard current.ownerUID == currentUID else {
                failures.append(
                    TerminationFailure(
                        identity: identity,
                        message: "Process belongs to another user"
                    )
                )
                continue
            }

            if let reason = ProcessProtection.reason(
                pid: identity.pid,
                name: current.name,
                path: current.path
            ) {
                failures.append(
                    TerminationFailure(
                        identity: identity,
                        message: reason
                    )
                )
                continue
            }

            if Darwin.kill(identity.pid, signal) == 0 {
                signalled.append(identity)
            } else if errno == ESRCH {
                alreadyStopped.append(identity)
            } else {
                failures.append(
                    TerminationFailure(
                        identity: identity,
                        message: String(cString: strerror(errno))
                    )
                )
            }
        }

        return TerminationResult(
            signalled: signalled,
            alreadyStopped: alreadyStopped,
            failures: failures
        )
    }

    private static func identityAndOwner(
        for pid: Int32
    ) -> (
        identity: ProcessIdentity,
        ownerUID: UInt32,
        name: String,
        path: String
    )? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return nil }

        return (
            ProcessIdentity(
                pid: pid,
                startedAtMicroseconds: info.pbi_start_tvsec * 1_000_000 + info.pbi_start_tvusec
            ),
            info.pbi_uid,
            processName(for: pid),
            processPath(for: pid)
        )
    }

    private static func processName(for pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(
            decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }

    private static func processPath(for pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 4_096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(
            decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }
}
