import CulpritCore
import SwiftUI

struct ProcessBranchBarView: View {
    let parent: ProcessGroup
    let branches: [ProcessBranch]
    let stopState: AppStore.StopState
    let capability: (ProcessBranch) -> TerminationCapability
    let onStop: (ProcessBranch) -> Void
    let onForceQuit: (ProcessBranch) -> Void

    private let visibleBranchCount = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Parts of this stack")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Stops a part + its children")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            branchMap

            ForEach(visibleBranches) { branch in
                branchRow(branch)
            }

            if hiddenBranches.count > 0 {
                hiddenBranchesMenu
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var branchMap: some View {
        GeometryReader { proxy in
            let itemCount = branches.count + 1
            let usableWidth = max(
                0,
                proxy.size.width - CGFloat(max(0, itemCount - 1))
            )

            HStack(spacing: 1) {
                ForEach(branches) { branch in
                    CulpritTheme.identityColor(for: branch.displayName)
                        .frame(
                            width: usableWidth * share(of: branch)
                        )
                }

                CulpritTheme.remainder
                    .frame(width: usableWidth * remainderShare)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
            )
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private func branchRow(
        _ branch: ProcessBranch
    ) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(
                    CulpritTheme.identityColor(
                        for: branch.displayName
                    )
                )
                .frame(width: 5, height: 12)

            Text(branch.displayName)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)

            Text(MetricFormatting.memory(branch.memoryBytes))
                .font(.system(size: 9, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tertiary)

            Spacer(minLength: 6)

            BranchStopControl(
                branch: branch,
                stopState: stopState,
                capability: capability(branch),
                stopLabel: "Stop",
                onStop: { onStop(branch) },
                onForceQuit: { onForceQuit(branch) }
            )
        }
        .frame(minHeight: 24)
        .accessibilityElement(children: .contain)
    }

    private var hiddenBranchesMenu: some View {
        Menu {
            ForEach(hiddenBranches) { branch in
                hiddenBranchAction(branch)
            }
        } label: {
            Text("\(hiddenBranches.count) more parts…")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func hiddenBranchAction(
        _ branch: ProcessBranch
    ) -> some View {
        let detail = "\(branch.displayName) · "
            + MetricFormatting.memory(branch.memoryBytes)
        let id = branch.asProcessGroup.id

        switch capability(branch) {
        case .allowed:
            if stopState == .forceAvailable(id) {
                Button("Force quit \(detail)") {
                    onForceQuit(branch)
                }
                .accessibilityLabel(
                    "Force quit \(branch.displayName) branch"
                )
            } else if stopState == .quitting(id)
                        || stopState == .forceKilling(id) {
                Button("Stopping \(detail)…") {}
                    .disabled(true)
                    .accessibilityLabel(
                        "Stopping \(branch.displayName) branch"
                    )
            } else {
                Button("Stop \(detail) + children") {
                    onStop(branch)
                }
                .disabled(stopState != .idle)
                .accessibilityLabel(
                    "Stop \(branch.displayName) branch and its children"
                )
            }

        case let .protected(reason):
            Button("Protected · \(detail)") {}
                .disabled(true)
                .help(reason)
                .accessibilityLabel(
                    "\(branch.displayName) branch is protected. \(reason)"
                )
        }
    }

    private var visibleBranches: ArraySlice<ProcessBranch> {
        branches.prefix(visibleBranchCount)
    }

    private var hiddenBranches: ArraySlice<ProcessBranch> {
        branches.dropFirst(visibleBranchCount)
    }

    private func share(
        of branch: ProcessBranch
    ) -> Double {
        guard parent.memoryBytes > 0 else { return 0 }
        return min(
            1,
            Double(branch.memoryBytes)
                / Double(parent.memoryBytes)
        )
    }

    private var remainderShare: Double {
        max(0, 1 - branches.reduce(0) {
            $0 + share(of: $1)
        })
    }
}
