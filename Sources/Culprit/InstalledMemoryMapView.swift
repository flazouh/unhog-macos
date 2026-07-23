import CulpritCore
import SwiftUI

struct InstalledMemoryMapView: View {
    let composition: MemoryComposition
    let focusedGroupID: ProcessGroupID?

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

            VStack(spacing: 5) {
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
                            let segmentWidth = usableWidth
                                * segment.shareOfInstalledRAM

                            memorySegment(
                                segment,
                                width: segmentWidth
                            )
                            .frame(
                                width: segmentWidth
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "\(segment.group.displayName), "
                                    + MetricFormatting.memory(segment.bytes)
                                    + (
                                        segment.group.id == focusedGroupID
                                            ? ", current issue"
                                            : ""
                                    )
                            )
                        }

                        let remainderWidth = usableWidth
                            * composition.remainderShare

                        remainderSegment(width: remainderWidth)
                            .frame(
                                width: remainderWidth
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "macOS, other apps, and unused memory, "
                                    + MetricFormatting.memory(
                                        composition.remainderBytes
                                    )
                            )
                    }
                    .frame(height: 18)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 5,
                            style: .continuous
                        )
                    )
                    .scaleEffect(
                        x: revealed ? 1 : 0,
                        y: 1,
                        anchor: .leading
                    )
                }
                .frame(height: 18)

                appKey
                    .opacity(revealed ? 1 : 0)
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

    private var appKey: some View {
        HStack(spacing: 0) {
            ForEach(composition.segments) { segment in
                HStack(spacing: 4) {
                    ProcessIconView(
                        group: segment.group,
                        size: 14
                    )

                    Text(segment.group.displayName)
                        .font(
                            .system(
                                size: 9,
                                weight: segment.group.id
                                    == focusedGroupID
                                    ? .semibold
                                    : .medium
                            )
                        )
                        .foregroundStyle(
                            segment.group.id == focusedGroupID
                                ? .primary
                                : .secondary
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }

            HStack(spacing: 4) {
                otherIcon(size: 14)
                Text("Other")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHidden(true)
    }

    private func memorySegment(
        _ segment: AppMemorySegment,
        width: CGFloat
    ) -> some View {
        ZStack {
            CulpritTheme.identityColor(
                for: segment.group.displayName
            )

            if width >= 11 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 3) {
                        ProcessIconView(
                            group: segment.group,
                            size: 11
                        )
                        Text(segment.group.displayName)
                            .font(.system(size: 7.5, weight: .semibold))
                        memoryValue(segment.bytes)
                    }
                    .foregroundStyle(Color.black.opacity(0.88))
                    .fixedSize()
                    .padding(.horizontal, 3)

                    HStack(spacing: 3) {
                        ProcessIconView(
                            group: segment.group,
                            size: 11
                        )
                        memoryValue(segment.bytes)
                    }
                    .fixedSize()
                    .padding(.horizontal, 2)

                    memoryValue(segment.bytes)
                        .fixedSize()

                    ProcessIconView(
                        group: segment.group,
                        size: 11
                    )

                    Color.clear
                        .frame(width: 0, height: 0)
                }
            }
        }
    }

    private func remainderSegment(
        width: CGFloat
    ) -> some View {
        ZStack {
            CulpritTheme.remainder

            if width >= 11 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 3) {
                        otherIcon(size: 11)
                        Text("Other")
                            .font(
                                .system(
                                    size: 7.5,
                                    weight: .medium
                                )
                            )
                        memoryValue(
                            composition.remainderBytes,
                            foreground: .secondary
                        )
                    }
                    .fixedSize()
                    .padding(.horizontal, 3)

                    HStack(spacing: 3) {
                        otherIcon(size: 11)
                        memoryValue(
                            composition.remainderBytes,
                            foreground: .secondary
                        )
                    }
                    .fixedSize()
                    .padding(.horizontal, 2)

                    memoryValue(
                        composition.remainderBytes,
                        foreground: .secondary
                    )
                    .fixedSize()

                    otherIcon(size: 11)

                    Color.clear
                        .frame(width: 0, height: 0)
                }
            }
        }
    }

    private func memoryValue(
        _ bytes: UInt64,
        foreground: Color = Color.black.opacity(0.88)
    ) -> some View {
        Text(MetricFormatting.memory(bytes))
            .font(
                .system(
                    size: 7.5,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(foreground)
            .lineLimit(1)
    }

    private func otherIcon(
        size: CGFloat
    ) -> some View {
        Image(systemName: "square.grid.2x2")
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(CulpritTheme.surfaceHover)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: size * 0.28,
                    style: .continuous
                )
            )
    }
}
