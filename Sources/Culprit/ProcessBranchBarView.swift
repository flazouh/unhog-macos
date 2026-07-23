import CulpritCore
import SwiftUI

struct ProcessBranchBarView: View {
    let parent: ProcessGroup
    let branches: [ProcessBranch]
    let stopState: AppStore.StopState
    let capability: (ProcessBranch) -> TerminationCapability
    let onStop: (ProcessBranch) -> Void
    let onForceQuit: (ProcessBranch) -> Void

    @State private var selectedID: ProcessBranchID?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Stop one part")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let itemCount = branches.count + 1
                let usableWidth = max(
                    0,
                    proxy.size.width - CGFloat(max(0, itemCount - 1))
                )

                HStack(spacing: 1) {
                    ForEach(
                        Array(branches.enumerated()),
                        id: \.element.id
                    ) { _, branch in
                        Button {
                            selectedID = branch.id
                        } label: {
                            CulpritTheme.identityColor(
                                for: branch.displayName
                            )
                                .opacity(
                                    selectedID == nil
                                        || selectedID == branch.id
                                        ? 1
                                        : 0.38
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: usableWidth
                                * share(of: branch)
                        )
                        .accessibilityLabel(
                            "\(branch.displayName), "
                                + MetricFormatting.memory(
                                    branch.memoryBytes
                                )
                        )
                        .accessibilityHint(
                            "Selects this branch for stopping"
                        )
                        .accessibilityHidden(true)
                    }

                    CulpritTheme.remainder
                        .frame(
                            width: usableWidth
                                * remainderShare
                        )
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 3,
                        style: .continuous
                    )
                )
            }
            .frame(height: 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(branches) { branch in
                        Button {
                            selectedID = branch.id
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Rectangle()
                                        .fill(
                                            CulpritTheme.identityColor(
                                                for: branch.displayName
                                            )
                                        )
                                        .frame(width: 5, height: 5)
                                    Text(branch.displayName)
                                        .lineLimit(1)
                                }
                                Text(
                                    MetricFormatting.memory(
                                        branch.memoryBytes
                                    )
                                )
                                .foregroundStyle(.tertiary)

                                Rectangle()
                                    .fill(
                                        selectedID == branch.id
                                            ? CulpritTheme.selection
                                            : .clear
                                    )
                                    .frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 8, weight: .medium))
                        .accessibilityValue(
                            selectedID == branch.id
                                ? "Selected"
                                : "Not selected"
                        )
                    }
                }
            }

            if let selected {
                HStack(spacing: 8) {
                    BranchStopControl(
                        branch: selected,
                        stopState: stopState,
                        capability: capability(selected),
                        stopLabel: "Stop \(selected.displayName)",
                        onStop: { onStop(selected) },
                        onForceQuit: { onForceQuit(selected) }
                    )

                    Text("Includes its child processes")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = branches.first?.id
            }
        }
        .onChange(of: branches.map(\.id)) {
            guard selected == nil else { return }
            selectedID = branches.first?.id
        }
    }

    private var selected: ProcessBranch? {
        branches.first { $0.id == selectedID }
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
