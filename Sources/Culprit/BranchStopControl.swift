import CulpritCore
import SwiftUI

struct BranchStopControl: View {
    let branch: ProcessBranch
    let stopState: AppStore.StopState
    let capability: TerminationCapability
    let stopLabel: String
    let onStop: () -> Void
    let onForceQuit: () -> Void

    var body: some View {
        switch capability {
        case .allowed:
            if stopState == .forceAvailable(branch.asProcessGroup.id) {
                Button("Force quit", action: onForceQuit)
                    .buttonStyle(.plain)
                    .foregroundStyle(CulpritTheme.destructive)
                    .accessibilityLabel(
                        "Force quit \(branch.displayName) branch"
                    )
            } else if isStoppingThisBranch {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Stopping…")
                        .font(.system(size: 9, weight: .semibold))
                }
                .accessibilityLabel(
                    "Stopping \(branch.displayName) branch"
                )
            } else {
                Button(stopLabel, action: onStop)
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(CulpritTheme.destructive)
                    .frame(minWidth: 34, minHeight: 24)
                    .contentShape(Rectangle())
                    .disabled(stopState != .idle)
                    .accessibilityLabel(
                        "Stop \(branch.displayName) branch and its children"
                    )
            }

        case let .protected(reason):
            Label("Protected", systemImage: "lock")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .help(reason)
                .accessibilityLabel("Cannot stop this branch. \(reason)")
        }
    }

    private var isStoppingThisBranch: Bool {
        let id = branch.asProcessGroup.id
        return stopState == .quitting(id)
            || stopState == .forceKilling(id)
    }
}
