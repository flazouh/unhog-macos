import CulpritCore
import SwiftUI

struct ProcessBranchBarView: View {
    let parent: ProcessGroup
    let branches: [ProcessBranch]
    let stopState: AppStore.StopState
    let capability: (ProcessBranch) -> TerminationCapability
    let onStop: (ProcessBranch) -> Void
    let onForceQuit: (ProcessBranch) -> Void

    @Environment(\.culpritReduceMotion) private var reduceMotion
    @State private var showsAllBranches = false

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

            ForEach(displayedBranches) { branch in
                branchRow(branch)
                    .transition(.opacity)
            }

            if hasHiddenBranches {
                branchDisclosure
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

    private var branchDisclosure: some View {
        Button {
            if reduceMotion {
                showsAllBranches.toggle()
            } else {
                withAnimation(CulpritTheme.motionEnter) {
                    showsAllBranches.toggle()
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(
                    showsAllBranches
                        ? "Show fewer"
                        : "\(hiddenBranchCount) more parts"
                )
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .rotationEffect(
                        .degrees(showsAllBranches ? 180 : 0)
                    )
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(minHeight: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            showsAllBranches
                ? "Show fewer stack parts"
                : "Show \(hiddenBranchCount) more stack parts"
        )
        .accessibilityValue(
            showsAllBranches ? "Expanded" : "Collapsed"
        )
    }

    private var displayedBranches: [ProcessBranch] {
        showsAllBranches
            ? branches
            : Array(branches.prefix(visibleBranchCount))
    }

    private var hasHiddenBranches: Bool {
        branches.count > visibleBranchCount
    }

    private var hiddenBranchCount: Int {
        max(0, branches.count - visibleBranchCount)
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
