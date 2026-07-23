import CulpritCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    ResourceLensView(store: store)
                    activity

                    if store.recoveryAssessment == nil,
                       let message = store.message {
                        messageRow(message)
                    }
                }
                .padding(.horizontal, CulpritTheme.pagePadding)
                .padding(.bottom, 14)
            }
        }
        .frame(
            width: CulpritTheme.popoverWidth,
            height: CulpritTheme.popoverHeight
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            "Stop this whole workload?",
            isPresented: Binding(
                get: { store.pendingQuitGroup != nil },
                set: { if !$0 { store.cancelPendingQuit() } }
            )
        ) {
            if let group = store.pendingQuitGroup {
                Button(
                    WorkloadPresentation.actionTitle(
                        for: group,
                        includesProjectName:
                            store.preferences.safety.showsProjectNames
                    )
                ) {
                    store.confirmPendingQuit()
                }
                Button("Cancel", role: .cancel) {
                    store.cancelPendingQuit()
                }
            }
        } message: {
            if let group = store.pendingQuitGroup {
                Text(
                    "This will ask \(group.processCount) process"
                        + (group.processCount == 1 ? "" : "es")
                        + " to quit."
                )
            }
        }
        .alert(
            "Force quit remaining processes?",
            isPresented: Binding(
                get: {
                    store.pendingForceQuitConfirmationID != nil
                },
                set: {
                    if !$0 {
                        store.cancelPendingForceQuitConfirmation()
                    }
                }
            )
        ) {
            Button("Force Quit", role: .destructive) {
                store.confirmPendingForceQuit()
            }
            Button("Cancel", role: .cancel) {
                store.cancelPendingForceQuitConfirmation()
            }
        } message: {
            Text(
                "Only the verified processes that ignored the normal quit "
                    + "request will be force quit."
            )
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: store.menuBarPresentation.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor)

            Text("Unhog")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Text(statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor)

            overflowMenu
        }
        .padding(.horizontal, CulpritTheme.pagePadding)
        .padding(.vertical, 11)
    }

    private var overflowMenu: some View {
        Menu {
            if store.isMonitoringPaused {
                Button("Resume monitoring") {
                    store.resumeMonitoring()
                }
            } else {
                Menu("Pause monitoring") {
                    Button("For 15 minutes") {
                        store.pauseMonitoring(for: 15 * 60)
                    }
                    Button("For 1 hour") {
                        store.pauseMonitoring(for: 60 * 60)
                    }
                    Button("Until I resume") {
                        store.pauseMonitoring(for: nil)
                    }
                }
            }

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }

            Divider()

            Button("Quit Unhog", role: .destructive) {
                store.quitApplication()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(.secondary)
        .accessibilityLabel("Unhog menu")
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.focusedGroupID == nil ? "Apps" : "Other apps")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            if displayedGroups.isEmpty {
                Text("No active user processes to show.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(displayedGroups) { group in
                        ProcessActivityRow(
                            group: group,
                            explanation: store.explanation(for: group),
                            signature: store.drainSignature(for: group),
                            branches: store.branches(for: group),
                            needsAttention: store.incidents.contains {
                                $0.id == group.id
                            },
                            showsProjectNames:
                                store.preferences.safety.showsProjectNames,
                            isExpanded: store.selectedGroupID == group.id,
                            stopState: store.stopState,
                            capability: store.capability(for: group),
                            onToggle: { store.toggleDetails(for: group.id) },
                            onQuit: { store.requestQuit(group.id) },
                            onForceQuit: { store.requestForceQuit(group.id) },
                            branchCapability: {
                                store.capability(for: $0)
                            },
                            onStopBranch: {
                                store.requestStopBranch($0)
                            },
                            onForceQuitBranch: {
                                store.requestForceQuit(
                                    $0.asProcessGroup.id
                                )
                            },
                            onMute: { store.muteAlerts(for: group) }
                        )
                    }
                }
            }
        }
    }

    private var displayedGroups: [ProcessGroup] {
        store.groups.filter { $0.id != store.focusedGroupID }
    }

    private func messageRow(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                store.dismissMessage()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss message")

        }
        .padding(12)
        .background(CulpritTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CulpritTheme.compactRadius))
    }

    private var statusText: String {
        if store.isMonitoringPaused { return "Paused" }
        if store.isPreparing { return "Checking" }
        if let recoveryAssessment = store.recoveryAssessment {
            switch recoveryAssessment {
            case .recovered:
                return "Recovered"
            case .restarted:
                return "Running again"
            case let .partial(_, remaining):
                return "\(remaining.count) still running"
            }
        }
        if store.incidents.isEmpty {
            return "No unusual drain"
        }
        return "\(store.incidents.count) app\(store.incidents.count == 1 ? "" : "s") need\(store.incidents.count == 1 ? "s" : "") attention"
    }

    private var statusColor: Color {
        if store.isPreparing { return .secondary }
        if case .restarted? = store.recoveryAssessment {
            return CulpritTheme.attention
        }
        if case .partial? = store.recoveryAssessment {
            return CulpritTheme.attention
        }
        return store.activeIncident == nil ? .secondary : CulpritTheme.attention
    }
}
