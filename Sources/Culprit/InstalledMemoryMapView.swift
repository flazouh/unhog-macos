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

            GeometryReader { proxy in
                let itemCount = composition.segments.count + 1
                let usableWidth = max(
                    0,
                    proxy.size.width - CGFloat(max(0, itemCount - 1))
                )

                ZStack(alignment: .topLeading) {
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

                    if let marker = focusedMarker(
                        usableWidth: usableWidth
                    ) {
                        Capsule()
                            .fill(marker.color)
                            .frame(width: 8, height: 2)
                            .offset(
                                x: marker.centerX - 4,
                                y: 16
                            )
                            .opacity(revealed ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 18)

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

    private func focusedMarker(
        usableWidth: CGFloat
    ) -> (centerX: CGFloat, color: Color)? {
        guard let focusedGroupID,
              let index = composition.segments.firstIndex(
                  where: { $0.group.id == focusedGroupID }
              )
        else {
            return nil
        }

        let precedingShare = composition.segments[..<index]
            .reduce(CGFloat.zero) {
                $0 + CGFloat($1.shareOfInstalledRAM)
            }
        let segment = composition.segments[index]
        let centerX = usableWidth
            * (
                precedingShare
                    + CGFloat(segment.shareOfInstalledRAM) / 2
            )
            + CGFloat(index)

        return (
            centerX,
            CulpritTheme.identityColor(for: segment.group.displayName)
        )
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
            Text(segment.group.displayName)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .font(.system(size: 9, weight: .medium))
    }

    private func memorySegment(
        _ segment: AppMemorySegment,
        width: CGFloat
    ) -> some View {
        ZStack {
            CulpritTheme.identityColor(
                for: segment.group.displayName
            )

            if width >= 24 {
                ViewThatFits(in: .horizontal) {
                    Text(MetricFormatting.memory(segment.bytes))
                        .font(
                            .system(
                                size: width >= 34 ? 7.5 : 7,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(Color.black.opacity(0.88))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, width >= 34 ? 2 : 0)

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

            if width >= 24 {
                ViewThatFits(in: .horizontal) {
                    Text(
                        MetricFormatting.memory(
                            composition.remainderBytes
                        )
                    )
                    .font(
                        .system(
                            size: 8,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 3)

                    Color.clear
                        .frame(width: 0, height: 0)
                }
            }
        }
    }
}
