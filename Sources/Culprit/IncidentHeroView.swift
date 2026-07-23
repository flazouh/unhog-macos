import CulpritCore
import SwiftUI

struct IncidentHeroView: View {
    let incident: ResourceIncident
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                ProcessIconView(group: incident.group, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.system(size: 17, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(primaryReading) for \(MetricFormatting.duration(incident.duration))")
                        .font(.system(size: 11))
                        .foregroundStyle(CulpritTheme.subtleText)

                    if let origin = incident.group.origin {
                        Text(origin)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack(spacing: 0) {
                metric(
                    MetricFormatting.ramShare(store.ramShare(for: incident.group)),
                    label: "Installed RAM"
                )
                metric(
                    MetricFormatting.cpu(incident.group.cpuPercent),
                    label: "CPU"
                )
                metric(
                    store.batteryEstimate(for: incident.group).rawValue,
                    label: "Battery · est."
                )
            }

            Text(impactExplanation)
                .font(.system(size: 11))
                .foregroundStyle(CulpritTheme.subtleText)
                .fixedSize(horizontal: false, vertical: true)

            action
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CulpritTheme.attention.opacity(0.075))
        .clipShape(
            RoundedRectangle(
                cornerRadius: CulpritTheme.cornerRadius,
                style: .continuous
            )
        )
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var action: some View {
        switch store.capability(for: incident.group) {
        case .allowed:
            if store.stopState == .forceAvailable(incident.group.id) {
                Button("Force quit \(incident.group.displayName)") {
                    store.requestForceQuit(incident.group.id)
                }
                .buttonStyle(BorderlessActionStyle(tone: .destructive))
            } else {
                Button(actionTitle) {
                    store.requestQuit(incident.group.id)
                }
                .buttonStyle(BorderlessActionStyle(tone: .primary))
                .disabled(isWorking)
            }

        case let .protected(reason):
            Label(reason, systemImage: "lock")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var isWorking: Bool {
        store.stopState == .quitting(incident.group.id)
            || store.stopState == .forceKilling(incident.group.id)
    }

    private var actionTitle: String {
        switch store.stopState {
        case .quitting(incident.group.id):
            "Stopping…"
        case .forceKilling(incident.group.id):
            "Force quitting…"
        default:
            switch incident.group.kind {
            case .application:
                "Quit \(incident.group.displayName)"
            case .playwright, .typeScript, .nx:
                "Stop \(incident.group.displayName)"
            }
        }
    }

    private var headline: String {
        switch incident.signal {
        case .memory:
            "\(incident.group.displayName) is using unusual memory"
        case .cpu:
            "\(incident.group.displayName) is keeping your CPU busy"
        }
    }

    private var primaryReading: String {
        switch incident.signal {
        case .memory:
            MetricFormatting.memory(incident.group.memoryBytes)
        case .cpu:
            MetricFormatting.cpu(incident.group.cpuPercent)
        }
    }

    private var impactExplanation: String {
        switch incident.signal {
        case .memory:
            "This may slow your Mac. CPU activity can also drain its battery."
        case .cpu:
            "This may drain your battery and make other apps slower."
        }
    }
}
