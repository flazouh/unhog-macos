import CulpritCore
import SwiftUI

struct ResourceLensView: View {
    @ObservedObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsEvidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            InstalledMemoryMapView(
                composition: store.memoryComposition,
                selectedGroupID: store.focusedGroupID,
                onSelect: { store.toggleDetails(for: $0) }
            )

            content
                .transition(.opacity)
        }
        .onChange(of: store.focusedGroupID) {
            showsEvidence = false
        }
    }

    @ViewBuilder
    private var content: some View {
        if let assessment = store.recoveryAssessment {
            recovery(assessment)
        } else if let group = store.resolvingGroup,
                  store.stopState != .idle {
            focusedWorkload(
                group: group,
                incident: store.incidents.first { $0.id == group.id }
            )
        } else if let incident = store.activeIncident {
            focusedWorkload(
                group: incident.group,
                incident: incident
            )
        } else if store.isPreparing {
            measuring
        } else {
            calm
        }
    }

    private var measuring: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Measuring current resource use")
                    .font(.system(size: 14, weight: .semibold))
                Text("The first useful CPU reading takes two samples.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private var calm: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Everything looks normal")
                    .font(.system(size: 14, weight: .semibold))
                Text("No app has sustained unusual CPU or memory use.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private func focusedWorkload(
        group: ProcessGroup,
        incident: ResourceIncident?
    ) -> some View {
        let explanation = store.explanation(for: group)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                ProcessIconView(group: group, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(explanation.workloadTitle) needs attention")
                        .font(.system(size: 16, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(workloadScope(group))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(
                    "\(MetricFormatting.memory(group.memoryBytes)) · "
                        + "\(MetricFormatting.ramShare(store.ramShare(for: group))) "
                        + "of installed RAM"
                )
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()

                Text(cpuDescription(group.cpuPercent))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(
                    "\(batteryDescription(store.batteryEstimate(for: group)))"
                        + durationSuffix(incident)
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            if showsEvidence {
                evidence(explanation)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            action(for: group)
        }
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(CulpritTheme.appColor(for: group.displayName))
                .frame(width: 3)
        }
        .accessibilityElement(children: .contain)
    }

    private func evidence(
        _ explanation: ResourceExplanation
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(explanation.processChain.joined(separator: "  →  "))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(2)

            Text(
                "\(explanation.topWorker.name) holds "
                    + "\(MetricFormatting.memory(explanation.topWorker.memoryBytes)) "
                    + "· \(Int((explanation.topWorker.memoryShare * 100).rounded()))% "
                    + "of this stack’s memory"
            )
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            Text("\(explanation.confidence.rawValue) confidence · process-tree evidence")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(CulpritTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: CulpritTheme.compactRadius,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private func action(for group: ProcessGroup) -> some View {
        switch store.capability(for: group) {
        case .allowed:
            if store.stopState == .quitting(group.id) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(
                        "Stopping \(WorkloadPresentation.shortName(for: group))…"
                    )
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 8) {
                    Button(stopActionTitle(group)) {
                        store.requestQuit(group.id)
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .primary))

                    evidenceButton
                }
            }

        case let .protected(reason):
            Label(reason, systemImage: "lock")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var evidenceButton: some View {
        Button {
            if reduceMotion {
                showsEvidence.toggle()
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    showsEvidence.toggle()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(showsEvidence ? "Hide why" : "See why")
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .rotationEffect(.degrees(showsEvidence ? 180 : 0))
            }
        }
        .buttonStyle(BorderlessActionStyle(tone: .secondary))
        .accessibilityValue(showsEvidence ? "Expanded" : "Collapsed")
        .accessibilityHint("Shows the process chain and top worker")
    }

    @ViewBuilder
    private func recovery(
        _ assessment: RecoveryAssessment
    ) -> some View {
        switch assessment {
        case let .recovered(receipt):
            receiptView(
                receipt,
                symbol: "checkmark.circle.fill",
                title: "Back to normal",
                detail: "Stopped \(receipt.stoppedProcessCount) process\(receipt.stoppedProcessCount == 1 ? "" : "es") safely",
                tone: .secondary
            )

        case let .restarted(receipt):
            receiptView(
                receipt,
                symbol: "arrow.clockwise.circle.fill",
                title: "\(receipt.contextLabel ?? receipt.displayName) is running again",
                detail: "A matching new \(receipt.displayName) workload appeared",
                tone: CulpritTheme.attention
            )

        case let .partial(receipt, remaining):
            partialRecovery(
                receipt: receipt,
                remainingCount: remaining.count
            )
        }
    }

    private func receiptView(
        _ receipt: RecoveryReceipt,
        symbol: String,
        title: String,
        detail: String,
        tone: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tone)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            comparison(receipt)

            Button("Done") {
                store.dismissRecovery()
            }
            .buttonStyle(BorderlessActionStyle(tone: .primary))

            if let message = store.message {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func comparison(
        _ receipt: RecoveryReceipt
    ) -> some View {
        HStack(spacing: 10) {
            comparisonMetric(
                label: "Stack memory",
                before: MetricFormatting.memory(receipt.before.memoryBytes),
                after: MetricFormatting.memory(receipt.after.memoryBytes)
            )
            comparisonMetric(
                label: "CPU",
                before: MetricFormatting.cpu(receipt.before.cpuPercent),
                after: MetricFormatting.cpu(receipt.after.cpuPercent)
            )
        }
    }

    private func comparisonMetric(
        label: String,
        before: String,
        after: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Text(before)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(after)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 12, design: .rounded))
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func partialRecovery(
        receipt: RecoveryReceipt,
        remainingCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                "\(remainingCount) process\(remainingCount == 1 ? "" : "es") did not stop",
                systemImage: "exclamationmark.circle"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CulpritTheme.attention)

            Text("Culprit stopped \(receipt.stoppedProcessCount) original process\(receipt.stoppedProcessCount == 1 ? "" : "es").")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if store.stopState == .forceAvailable(receipt.originalGroupID) {
                    Button("Force quit \(remainingCount)") {
                        store.requestForceQuit(receipt.originalGroupID)
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .destructive))

                    Button("Cancel") {
                        store.cancelPendingForceQuit()
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .secondary))
                } else if store.stopState
                    == .forceKilling(receipt.originalGroupID) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Force quitting…")
                        .font(.system(size: 11, weight: .medium))
                } else {
                    Button("Done") {
                        store.dismissRecovery()
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .primary))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func workloadScope(_ group: ProcessGroup) -> String {
        let childCount = max(0, group.processCount - 1)
        guard childCount > 0 else {
            return group.displayName
        }
        return "\(group.displayName) + \(childCount) child process\(childCount == 1 ? "" : "es")"
    }

    private func stopActionTitle(_ group: ProcessGroup) -> String {
        WorkloadPresentation.actionTitle(for: group)
    }

    private func cpuDescription(_ cpuPercent: Double) -> String {
        guard cpuPercent >= 10 else {
            return "\(MetricFormatting.cpu(cpuPercent)) CPU"
        }
        let cores = cpuPercent / 100
        let displayedCores = (cores * 10).rounded() / 10
        let unit = displayedCores == 1 ? "core" : "cores"
        return "\(MetricFormatting.cpu(cpuPercent)) CPU · about \(String(format: "%.1f", displayedCores)) \(unit)"
    }

    private func batteryDescription(
        _ estimate: BatteryDrainEstimate
    ) -> String {
        switch estimate {
        case .low:
            "Battery drain looks low"
        case .elevated:
            "Battery drain may be elevated"
        case .high:
            "Battery drain likely high"
        }
    }

    private func durationSuffix(
        _ incident: ResourceIncident?
    ) -> String {
        guard let incident else { return "" }
        return " · sustained for \(MetricFormatting.duration(incident.duration))"
    }
}
