import CulpritCore
import SwiftUI

struct InstalledMemoryMapView: View {
    let composition: MemoryComposition
    let selectedGroupID: ProcessGroupID?
    let onSelect: (ProcessGroupID) -> Void

    @Environment(\.culpritReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(
                    "\(MetricFormatting.memory(composition.installedBytes)) memory"
                )
                .font(.system(size: 12, weight: .semibold))

                Spacer()

                Text("100% of installed RAM")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let itemCount = composition.segments.count + 1
                let usableWidth = max(
                    0,
                    proxy.size.width - CGFloat(max(0, itemCount - 1))
                )

                HStack(spacing: 1) {
                    ForEach(
                        Array(composition.segments.enumerated()),
                        id: \.element.id
                    ) { _, segment in
                        Button {
                            onSelect(segment.id)
                        } label: {
                            CulpritTheme.identityColor(
                                for: segment.group.displayName
                            )
                                .opacity(
                                    selectedGroupID == nil
                                        || selectedGroupID == segment.id
                                        ? 1
                                        : 0.38
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: usableWidth
                                * segment.shareOfInstalledRAM
                        )
                        .contentShape(Rectangle())
                        .accessibilityLabel(
                            "\(segment.group.displayName), "
                                + MetricFormatting.memory(segment.bytes)
                        )
                        .accessibilityValue(
                            selectedGroupID == segment.id
                                ? "Selected"
                                : "Not selected"
                        )
                        .accessibilityHint(
                            "Shows this workload's details"
                        )
                    }

                    CulpritTheme.remainder
                        .frame(
                            width: usableWidth
                                * composition.remainderShare
                        )
                        .accessibilityLabel(
                            "macOS, other apps, and unused memory, "
                                + MetricFormatting.memory(
                                    composition.remainderBytes
                                )
                        )
                }
                .frame(height: 14)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                )
                .scaleEffect(
                    x: revealed ? 1 : 0,
                    y: 1,
                    anchor: .leading
                )
            }
            .frame(height: 14)

            HStack(spacing: 8) {
                ForEach(
                    Array(composition.segments.enumerated()),
                    id: \.element.id
                ) { _, segment in
                    legendItem(segment)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(CulpritTheme.remainder)
                        .frame(width: 5, height: 5)
                    Text("Other")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(CulpritTheme.motionEnter) {
                    revealed = true
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func legendItem(
        _ segment: AppMemorySegment
    ) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(
                    CulpritTheme.identityColor(
                        for: segment.group.displayName
                    )
                )
                .frame(width: 5, height: 5)
            Text(
                "\(segment.group.displayName) "
                    + MetricFormatting.memory(segment.bytes)
            )
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .font(.system(size: 9, weight: .medium))
    }
}
