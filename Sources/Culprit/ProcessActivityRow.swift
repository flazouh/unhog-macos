import CulpritCore
import SwiftUI

struct ProcessActivityRow: View {
    let group: ProcessGroup
    let explanation: ResourceExplanation
    let signature: DrainSignature
    let branches: [ProcessBranch]
    let needsAttention: Bool
    let showsProjectNames: Bool
    let isExpanded: Bool
    let stopState: AppStore.StopState
    let capability: TerminationCapability
    let onToggle: () -> Void
    let onQuit: () -> Void
    let onForceQuit: () -> Void
    let branchCapability: (ProcessBranch) -> TerminationCapability
    let onStopBranch: (ProcessBranch) -> Void
    let onForceQuitBranch: (ProcessBranch) -> Void
    let onMute: () -> Void

    @State private var isHovered = false
    @Environment(\.culpritReduceMotion) private var reduceMotion

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
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(CulpritTheme.attention)
                            }
                        }

                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    ResourceSignatureView(
                        signature: signature,
                        color: CulpritTheme.appColor(
                            for: group.displayName
                        ),
                        compact: true
                    )
                    .frame(width: 116)

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
            .accessibilityLabel(
                "\(group.displayName), \(MetricFormatting.memory(group.memoryBytes)), "
                    + "\(MetricFormatting.cpu(group.cpuPercent)) CPU"
            )
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows why this workload is using resources")

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
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isExpanded
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            ResourceSignatureView(
                signature: signature,
                color: CulpritTheme.appColor(for: group.displayName)
            )

            if !branches.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("MAIN BRANCHES")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(branches) { branch in
                        branchRow(branch)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text(explanation.processChain.joined(separator: "  →  "))
                        .font(
                            .system(
                                size: 10,
                                weight: .medium,
                                design: .monospaced
                            )
                        )

                    Text(
                        "\(explanation.topWorker.name) is the top worker · "
                            + MetricFormatting.memory(
                                explanation.topWorker.memoryBytes
                            )
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                }
            }

            action
        }
    }

    private func branchRow(_ branch: ProcessBranch) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(branch.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text(
                    "\(branch.processCount) process"
                        + (branch.processCount == 1 ? "" : "es")
                        + " · \(MetricFormatting.memory(branch.memoryBytes))"
                )
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
            Spacer()
            BranchStopControl(
                branch: branch,
                stopState: stopState,
                capability: branchCapability(branch),
                stopLabel: "Stop branch",
                onStop: { onStopBranch(branch) },
                onForceQuit: { onForceQuitBranch(branch) }
            )
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var action: some View {
        switch capability {
        case .allowed:
            if stopState == .forceAvailable(group.id) {
                Button("Force quit \(group.displayName)", action: onForceQuit)
                    .buttonStyle(BorderlessActionStyle(tone: .destructive))
            } else {
                HStack(spacing: 8) {
                    Button(buttonTitle, action: onQuit)
                        .buttonStyle(BorderlessActionStyle(tone: .secondary))
                        .disabled(stopState != .idle)
                    Button("Mute alerts", action: onMute)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
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
        return WorkloadPresentation.actionTitle(
            for: group,
            includesProjectName: showsProjectNames
        )
    }

    private var subtitle: String {
        let count = "\(group.processCount) process\(group.processCount == 1 ? "" : "es")"
        if showsProjectNames, let context = group.contextLabel {
            return context
        }
        return group.origin ?? count
    }
}
