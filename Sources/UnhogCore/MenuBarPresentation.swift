import Foundation

public enum MenuBarPhase: Hashable, Sendable {
    case measuring
    case calm
    case paused
    case attention(ResourceIncident)
    case stopping(ResourceIncident?)
    case recovered(RecoveryReceipt)
    case restarted(RecoveryReceipt)
    case partial(RecoveryReceipt, remainingCount: Int)
}

public struct MenuBarPresentation: Equatable, Sendable {
    public let symbolName: String
    public let compactLabel: String?
    public let accessibilityLabel: String

    public init(
        symbolName: String,
        compactLabel: String?,
        accessibilityLabel: String
    ) {
        self.symbolName = symbolName
        self.compactLabel = compactLabel
        self.accessibilityLabel = accessibilityLabel
    }

    public static func make(
        phase: MenuBarPhase,
        leadingGroup: ProcessGroup?,
        installedMemoryBytes: UInt64,
        displayMode: MenuBarDisplayMode
    ) -> MenuBarPresentation {
        let base = basePresentation(
            phase: phase,
            installedMemoryBytes: installedMemoryBytes
        )

        switch displayMode {
        case .iconOnly:
            return MenuBarPresentation(
                symbolName: base.symbolName,
                compactLabel: nil,
                accessibilityLabel: base.accessibilityLabel
            )
        case .adaptive:
            if case .restarted = phase, let leadingGroup {
                let label = leadingGroup.cpuPercent >= 100
                    ? cpuLabel(leadingGroup.cpuPercent)
                    : memoryShareLabel(
                        bytes: leadingGroup.memoryBytes,
                        installed: installedMemoryBytes
                    )
                return MenuBarPresentation(
                    symbolName: base.symbolName,
                    compactLabel: label,
                    accessibilityLabel:
                        "\(base.accessibilityLabel) It is now using "
                        + spokenMetric(
                            group: leadingGroup,
                            signal: leadingGroup.cpuPercent >= 100
                                ? .cpu
                                : .memory,
                            installedMemoryBytes: installedMemoryBytes
                        )
                        + "."
                )
            }
            return base
        case .topCPU:
            guard let leadingGroup else { return base }
            return MenuBarPresentation(
                symbolName: base.symbolName,
                compactLabel: cpuLabel(leadingGroup.cpuPercent),
                accessibilityLabel:
                    "\(base.accessibilityLabel) Top workload "
                    + "\(leadingGroup.displayName) is using about "
                    + "\(decimal(leadingGroup.cpuPercent / 100)) "
                    + "processor cores."
            )
        case .topMemory:
            guard let leadingGroup else { return base }
            let share = memoryShareLabel(
                bytes: leadingGroup.memoryBytes,
                installed: installedMemoryBytes
            )
            return MenuBarPresentation(
                symbolName: base.symbolName,
                compactLabel: share,
                accessibilityLabel:
                    "\(base.accessibilityLabel) Top workload "
                    + "\(leadingGroup.displayName) is using \(share) "
                    + "of installed memory."
            )
        }
    }

    private static func basePresentation(
        phase: MenuBarPhase,
        installedMemoryBytes: UInt64
    ) -> MenuBarPresentation {
        switch phase {
        case .measuring:
            return .init(
                symbolName: UnhogSymbolName.loading,
                compactLabel: nil,
                accessibilityLabel: "Unhog. Measuring system activity."
            )
        case .calm:
            return .init(
                symbolName: "circle",
                compactLabel: nil,
                accessibilityLabel: "Unhog. No unusual resource drain."
            )
        case .paused:
            return .init(
                symbolName: "pause.circle",
                compactLabel: nil,
                accessibilityLabel: "Unhog. Monitoring is paused."
            )
        case let .attention(incident):
            let isHigh = incident.severity == .high
            return .init(
                symbolName: isHigh
                    ? "exclamationmark.circle.fill"
                    : "exclamationmark.circle",
                compactLabel: incidentLabel(
                    incident,
                    installedMemoryBytes: installedMemoryBytes
                ),
                accessibilityLabel: incidentAccessibilityLabel(
                    incident,
                    installedMemoryBytes: installedMemoryBytes
                )
            )
        case let .stopping(incident):
            return .init(
                symbolName: UnhogSymbolName.loading,
                compactLabel: incident.map {
                    incidentLabel(
                        $0,
                        installedMemoryBytes: installedMemoryBytes
                    )
                },
                accessibilityLabel: incident.map {
                    "Unhog. Stopping \($0.group.displayName)."
                } ?? "Unhog. Stopping the selected workload."
            )
        case let .recovered(receipt):
            let metric = recoveredMetric(receipt)
            return .init(
                symbolName: "checkmark.circle",
                compactLabel: metric.compact,
                accessibilityLabel:
                    "Unhog. Resource use recovered. \(metric.spoken)"
            )
        case let .restarted(receipt):
            return .init(
                symbolName: "arrow.clockwise.circle",
                compactLabel: nil,
                accessibilityLabel:
                    "Unhog. \(receipt.displayName) restarted after it was stopped."
            )
        case let .partial(_, remainingCount):
            return .init(
                symbolName: "exclamationmark.triangle",
                compactLabel: "\(remainingCount)",
                accessibilityLabel:
                    "Unhog. \(remainingCount) targeted process"
                    + (remainingCount == 1 ? " is" : "es are")
                    + " still running."
            )
        }
    }

    private static func incidentLabel(
        _ incident: ResourceIncident,
        installedMemoryBytes: UInt64
    ) -> String {
        switch incident.signal {
        case .cpu:
            cpuLabel(incident.group.cpuPercent)
        case .memory:
            memoryShareLabel(
                bytes: incident.group.memoryBytes,
                installed: installedMemoryBytes
            )
        }
    }

    private static func incidentAccessibilityLabel(
        _ incident: ResourceIncident,
        installedMemoryBytes: UInt64
    ) -> String {
        switch incident.signal {
        case .cpu:
            let cores = decimal(incident.group.cpuPercent / 100)
            return "Unhog. \(incident.group.displayName) needs attention and is using about \(cores) processor cores."
        case .memory:
            let share = memoryShareLabel(
                bytes: incident.group.memoryBytes,
                installed: installedMemoryBytes
            )
            return "Unhog. \(incident.group.displayName) needs attention and is using \(share) of installed memory."
        }
    }

    private static func spokenMetric(
        group: ProcessGroup,
        signal: ResourceSignal,
        installedMemoryBytes: UInt64
    ) -> String {
        switch signal {
        case .cpu:
            "about \(decimal(group.cpuPercent / 100)) processor cores"
        case .memory:
            memoryShareLabel(
                bytes: group.memoryBytes,
                installed: installedMemoryBytes
            ) + " of installed memory"
        }
    }

    private static func cpuLabel(_ cpuPercent: Double) -> String {
        "\(decimal(cpuPercent / 100))c"
    }

    private static func memoryShareLabel(
        bytes: UInt64,
        installed: UInt64
    ) -> String {
        guard installed > 0 else { return "0%" }
        let percent = Int(
            (Double(bytes) / Double(installed) * 100).rounded()
        )
        return "\(min(100, max(0, percent)))%"
    }

    private static func recoveredMetric(
        _ receipt: RecoveryReceipt
    ) -> (compact: String?, spoken: String) {
        if receipt.memoryReductionBytes >= 100_000_000 {
            let gigabytes = decimal(
                Double(receipt.memoryReductionBytes) / 1_000_000_000
            )
            return (
                "\(gigabytes) GB",
                "Workload memory fell by \(gigabytes) gigabytes."
            )
        }
        if receipt.cpuDropPoints >= 10 {
            let cores = decimal(receipt.cpuDropPoints / 100)
            return ("\(cores)c", "Processor use fell by about \(cores) cores.")
        }
        return (nil, "The targeted workload is no longer running.")
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
