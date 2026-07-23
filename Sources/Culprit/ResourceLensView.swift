import CulpritCore
import SwiftUI

struct ResourceLensView: View {
    @ObservedObject var store: AppStore
    @Environment(\.culpritReduceMotion) private var reduceMotion

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
        if store.isMonitoringPaused {
            paused
        } else if let assessment = store.recoveryAssessment {
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

    private var paused: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "pause.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text("Monitoring is paused")
                    .font(.system(size: 14, weight: .semibold))
                Text("Culprit is not sampling processes or sending alerts.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Resume") {
                    store.resumeMonitoring()
                }
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 5)
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

            ResourceSignatureView(
                signature: store.drainSignature(for: group),
                color: CulpritTheme.appColor(for: group.displayName)
            )

            if let incident {
                Text(
                    "Sustained for "
                        + MetricFormatting.duration(incident.duration)
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }

            if showsEvidence {
                evidence(group: group, explanation: explanation)
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
        group: ProcessGroup,
        explanation: ResourceExplanation
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

            let branches = store.branches(for: group)
            if !branches.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                Text("STOP ONE BRANCH")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(branches) { branch in
                    focusedBranchRow(branch)
                }
            }
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

    private func focusedBranchRow(
        _ branch: ProcessBranch
    ) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
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
                stopState: store.stopState,
                capability: store.capability(for: branch),
                stopLabel: "Stop",
                onStop: { store.requestStopBranch(branch) },
                onForceQuit: {
                    store.requestForceQuit(branch.asProcessGroup.id)
                }
            )
        }
    }

    @ViewBuilder
    private func action(for group: ProcessGroup) -> some View {
        switch store.capability(for: group) {
        case .allowed:
            if store.stopState == .quitting(group.id) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(stoppingTitle(group))
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 8) {
                    Button(stopActionTitle(group)) {
                        store.requestQuit(group.id)
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .primary))
                    .disabled(store.stopState != .idle)

                    evidenceButton

                    Button {
                        store.muteAlerts(for: group)
                    } label: {
                        Image(systemName: "bell.slash")
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .secondary))
                    .accessibilityLabel(
                        "Mute alerts for \(group.displayName)"
                    )
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
                title: recoveredTitle(receipt),
                detail: recoveredDetail(receipt),
                tone: .secondary
            )

        case let .restarted(receipt):
            receiptView(
                receipt,
                symbol: "arrow.clockwise.circle.fill",
                title: "\(recoveryDisplayName(receipt)) is running again",
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
                label: receipt.scope == .branch
                    ? "Branch memory"
                    : "Stack memory",
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

    private func recoveryDisplayName(_ receipt: RecoveryReceipt) -> String {
        guard store.preferences.safety.showsProjectNames else {
            return receipt.displayName
        }
        return receipt.contextLabel ?? receipt.displayName
    }

    private func recoveredTitle(_ receipt: RecoveryReceipt) -> String {
        receipt.scope == .branch
            ? "\(receipt.displayName) stopped"
            : "Back to normal"
    }

    private func recoveredDetail(_ receipt: RecoveryReceipt) -> String {
        if receipt.scope == .branch {
            return "The rest of the workload is still running"
        }
        return "Stopped \(receipt.stoppedProcessCount) process"
            + (receipt.stoppedProcessCount == 1 ? "" : "es")
            + " safely"
    }

    private func stopActionTitle(_ group: ProcessGroup) -> String {
        WorkloadPresentation.actionTitle(
            for: group,
            includesProjectName:
                store.preferences.safety.showsProjectNames
        )
    }

    private func stoppingTitle(_ group: ProcessGroup) -> String {
        let name = WorkloadPresentation.shortName(
            for: group,
            includesProjectName:
                store.preferences.safety.showsProjectNames
        )
        return "Stopping \(name)…"
    }

}
