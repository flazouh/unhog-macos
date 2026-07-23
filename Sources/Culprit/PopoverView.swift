import CulpritCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    hero
                    memoryMap
                    activity

                    if case let .forceAvailable(id) = store.stopState {
                        pendingForceSurface(id: id)
                    } else if let message = store.message {
                        messageRow(message)
                    }
                }
                .padding(.horizontal, CulpritTheme.pagePadding)
                .padding(.bottom, 14)
            }

            footer
        }
        .frame(
            width: CulpritTheme.popoverWidth,
            height: CulpritTheme.popoverHeight
        )
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

            Text(statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, CulpritTheme.pagePadding)
        .padding(.vertical, 13)
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
        HStack(spacing: 11) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 3) {
                Text("Measuring current resource use")
                    .font(.system(size: 15, weight: .semibold))
                Text("The first useful CPU reading takes two samples.")
                    .font(.system(size: 10))
                    .foregroundStyle(CulpritTheme.subtleText)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var calmHero: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Everything looks normal")
                    .font(.system(size: 15, weight: .semibold))
                Text("No app has sustained unusual CPU or memory use.")
                    .font(.system(size: 10))
                    .foregroundStyle(CulpritTheme.subtleText)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var memoryMap: some View {
        InstalledMemoryMapView(
            composition: store.memoryComposition,
            selectedGroupID: store.selectedGroupID,
            onSelect: { store.toggleDetails(for: $0) }
        )
        .padding(.vertical, 2)
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Apps")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("RAM · CPU · battery estimate")
                    .font(.system(size: 9))
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
                            ramShare: store.ramShare(for: group),
                            batteryEstimate: store.batteryEstimate(for: group),
                            needsAttention: store.incidents.contains {
                                $0.id == group.id
                            },
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
        .padding(.vertical, 11)
        .background(CulpritTheme.surface.opacity(0.65))
    }

    private var statusText: String {
        if store.isPreparing { return "Checking" }
        if store.incidents.isEmpty {
            return "No unusual drain"
        }
        return "\(store.incidents.count) need\(store.incidents.count == 1 ? "s" : "") attention"
    }

    private var statusColor: Color {
        if store.isPreparing { return .secondary }
        return store.activeIncident == nil ? .secondary : CulpritTheme.attention
    }
}
