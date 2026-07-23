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
                    ProcessIconView(group: group, size: 27)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(group.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            if needsAttention {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(CulpritTheme.destructive)
                                        .frame(width: 4, height: 4)
                                    Text("draining")
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(CulpritTheme.destructive)
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
                        compact: true
                    )
                    .frame(width: 108)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(
                            isExpanded ? .primary : .secondary
                        )
                        .frame(width: 22, height: 22)
                        .background(
                            isExpanded
                                ? CulpritTheme.surfaceHover
                                : CulpritTheme.surface
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 6,
                                style: .continuous
                            )
                        )
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
            .help(isExpanded ? "Hide details" : "Show details")

            if isExpanded {
                details
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(
                                    scale: 0.97,
                                    anchor: .top
                                )
                            )
                    )
            }
        }
        .background(isHovered ? CulpritTheme.surface : .clear)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
        )
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion
                ? CulpritTheme.motionFade
                : CulpritTheme.motionEnter,
            value: isExpanded
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(explanation.processChain.joined(separator: "  →  "))
                .font(
                    .system(
                        size: 9,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.secondary)

            if !branches.isEmpty {
                ProcessBranchBarView(
                    parent: group,
                    branches: branches,
                    stopState: stopState,
                    capability: branchCapability,
                    onStop: onStopBranch,
                    onForceQuit: onForceQuitBranch
                )
            } else {
                Text(
                    "\(explanation.topWorker.name) is the top worker · "
                        + MetricFormatting.memory(
                            explanation.topWorker.memoryBytes
                        )
                )
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
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
                HStack(spacing: 8) {
                    Button(action: onQuit) {
                        HStack(spacing: 7) {
                            if isWorking {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(buttonTitle)
                                .lineLimit(1)
                        }
                    }
                        .buttonStyle(BorderlessActionStyle(tone: .secondary))
                        .disabled(stopState != .idle)
                        .accessibilityLabel(
                            isWorking
                                ? "Stopping \(group.displayName)"
                                : buttonTitle
                        )
                    Button("Mute alerts", action: onMute)
                        .buttonStyle(InlineActionStyle())
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
