import CulpritCore
import SwiftUI

struct ProcessActivityRow: View {
    let group: ProcessGroup
    let ramShare: Double
    let batteryEstimate: BatteryDrainEstimate
    let needsAttention: Bool
    let isExpanded: Bool
    let stopState: AppStore.StopState
    let capability: TerminationCapability
    let onToggle: () -> Void
    let onQuit: () -> Void
    let onForceQuit: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(CulpritTheme.appColor(for: group.displayName))
                        .frame(width: 7, height: 7)

                    ProcessIconView(group: group, size: 27)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(group.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            if needsAttention {
                                Text("Attention")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(CulpritTheme.attention)
                            }
                        }

                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            "\(MetricFormatting.memory(group.memoryBytes)) · "
                                + "\(MetricFormatting.ramShare(ramShare)) RAM"
                        )
                            .tabularMetric()
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(
                            "\(MetricFormatting.cpu(group.cpuPercent)) CPU · "
                                + "\(batteryEstimate.rawValue) est."
                        )
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            if isExpanded {
                details
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isHovered || isExpanded ? CulpritTheme.surfaceHover : .clear)
        .clipShape(
            RoundedRectangle(
                cornerRadius: CulpritTheme.compactRadius,
                style: .continuous
            )
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.16), value: isExpanded)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(group.processes.prefix(5), id: \.identity) { process in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 4, height: 4)
                        Text(process.name)
                            .lineLimit(1)
                        Spacer()
                        Text("PID \(process.identity.pid)")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 10))
                }

                if group.processCount > 5 {
                    Text("+ \(group.processCount - 5) more")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 12)
                }
            }

            action
        }
    }

    @ViewBuilder
    private var action: some View {
        switch capability {
        case .allowed:
            if stopState == .forceAvailable(group.id) {
                Button("Force quit \(group.displayName)", action: onForceQuit)
                    .buttonStyle(BorderlessActionStyle(tone: .destructive))
            } else {
                Button(buttonTitle, action: onQuit)
                    .buttonStyle(BorderlessActionStyle(tone: .secondary))
                    .disabled(isWorking)
            }
        case let .protected(reason):
            Label(reason, systemImage: "lock")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var isWorking: Bool {
        stopState == .quitting(group.id) || stopState == .forceKilling(group.id)
    }

    private var buttonTitle: String {
        if isWorking { return "Stopping…" }
        return "Quit \(group.displayName)"
    }

    private var subtitle: String {
        let count = "\(group.processCount) process\(group.processCount == 1 ? "" : "es")"
        if let context = group.contextLabel {
            return context
        }
        return group.origin ?? count
    }
}
