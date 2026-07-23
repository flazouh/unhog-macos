import CulpritCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    activity

                    if case let .forceAvailable(id) = store.stopState {
                        pendingForceSurface(id: id)
                    } else if let message = store.message {
                        messageRow(message)
                    }
                }
                .padding(.horizontal, CulpritTheme.pagePadding)
                .padding(.bottom, 18)
            }

            footer
        }
        .frame(width: CulpritTheme.popoverWidth, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: store.menuBarSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor)

            Text("Culprit")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Text(statusText.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, CulpritTheme.pagePadding)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var hero: some View {
        if store.isPreparing {
            preparingHero
        } else if let incident = store.activeIncident {
            IncidentHeroView(incident: incident, store: store)
        } else {
            calmHero
        }
    }

    private var preparingHero: some View {
        SoftSurface {
            HStack(spacing: 14) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learning what normal looks like")
                        .font(.system(size: 16, weight: .semibold))
                    Text("The first useful CPU reading takes two samples.")
                        .font(.system(size: 12))
                        .foregroundStyle(CulpritTheme.subtleText)
                }
                Spacer()
            }
        }
    }

    private var calmHero: some View {
        SoftSurface {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Everything looks calm")
                        .font(.system(size: 19, weight: .semibold))
                    Text("No process family has sustained dangerous CPU or memory use.")
                        .font(.system(size: 12))
                        .foregroundStyle(CulpritTheme.subtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("adaptive sampling")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)

            if store.groups.isEmpty {
                Text("No active user processes to show.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.groups) { group in
                        ProcessActivityRow(
                            group: group,
                            isExpanded: store.selectedGroupID == group.id,
                            stopState: store.stopState,
                            capability: store.capability(for: group),
                            onToggle: { store.toggleDetails(for: group.id) },
                            onQuit: { store.requestQuit(group.id) },
                            onForceQuit: { store.requestForceQuit(group.id) }
                        )
                    }
                }
            }
        }
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

    private func pendingForceSurface(id: ProcessGroupID) -> some View {
        SoftSurface {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.pendingForceName ?? "Process family") did not quit")
                        .font(.system(size: 13, weight: .semibold))
                    Text(store.message ?? "Some original processes are still running.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Force quit") {
                        store.requestForceQuit(id)
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .destructive))

                    Button("Cancel") {
                        store.cancelPendingForceQuit()
                    }
                    .buttonStyle(BorderlessActionStyle(tone: .secondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Quit Culprit") {
                store.quitApplication()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, CulpritTheme.pagePadding)
        .padding(.vertical, 13)
        .background(CulpritTheme.surface.opacity(0.65))
    }

    private var statusText: String {
        if store.isPreparing { return "Checking" }
        switch store.activeIncident?.severity {
        case .warning: return "Hot"
        case .critical: return "Critical"
        case nil: return "Quiet"
        }
    }

    private var statusColor: Color {
        if store.isPreparing { return .secondary }
        switch store.activeIncident?.severity {
        case .warning: return CulpritTheme.warning
        case .critical: return CulpritTheme.critical
        case nil: return .secondary
        }
    }
}
