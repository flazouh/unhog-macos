import CulpritCore
import SwiftUI

struct IncidentHeroView: View {
    let incident: HeatIncident
    @ObservedObject var store: AppStore

    var body: some View {
        SoftSurface {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top, spacing: 12) {
                    ProcessIconView(group: incident.group, size: 38)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(incident.group.displayName) is making your Mac hot")
                            .font(.system(size: 19, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        if let origin = incident.group.origin {
                            Text(origin)
                                .font(.system(size: 12))
                                .foregroundStyle(CulpritTheme.subtleText)
                        }
                    }
                }

                HStack(spacing: 0) {
                    metric(
                        MetricFormatting.cpu(incident.group.cpuPercent),
                        label: "CPU"
                    )
                    metric(
                        MetricFormatting.memory(incident.group.memoryBytes),
                        label: "Memory"
                    )
                    metric(
                        MetricFormatting.duration(incident.duration),
                        label: "Duration"
                    )
                }

                Text(incident.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(CulpritTheme.subtleText)

                action
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            "Quitting…"
        case .forceKilling(incident.group.id):
            "Force quitting…"
        default:
            "Quit \(incident.group.displayName)"
        }
    }
}
