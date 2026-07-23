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

            VStack(spacing: 0) {
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

                GeometryReader { proxy in
                    linkedLegend(size: proxy.size)
                }
                .frame(height: 23)
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

    private func linkedLegend(
        size: CGSize
    ) -> some View {
        let itemCount = composition.segments.count + 1
        let usableWidth = max(
            0,
            size.width - CGFloat(max(0, itemCount - 1))
        )

        return ZStack(alignment: .top) {
            Canvas { context, canvasSize in
                for (index, segment) in
                    composition.segments.enumerated()
                {
                    let sourceX = segmentCenterX(
                        at: index,
                        usableWidth: usableWidth
                    )
                    let targetX = labelCenterX(
                        at: index,
                        width: canvasSize.width,
                        itemCount: itemCount
                    )
                    let isFocused = segment.group.id
                        == focusedGroupID

                    context.stroke(
                        bezierLeaderPath(
                            fromX: sourceX,
                            toX: targetX
                        ),
                        with: .color(
                            CulpritTheme.identityColor(
                                for: segment.group.displayName
                            )
                            .opacity(isFocused ? 0.95 : 0.5)
                        ),
                        style: StrokeStyle(
                            lineWidth: isFocused ? 1.5 : 1,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                let remainderSourceX = remainderCenterX(
                    usableWidth: usableWidth
                )
                let remainderTargetX = labelCenterX(
                    at: itemCount - 1,
                    width: canvasSize.width,
                    itemCount: itemCount
                )
                context.stroke(
                    bezierLeaderPath(
                        fromX: remainderSourceX,
                        toX: remainderTargetX
                    ),
                    with: .color(Color.secondary.opacity(0.24)),
                    style: StrokeStyle(
                        lineWidth: 1,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
            .frame(height: 9)
            .opacity(revealed ? 1 : 0)

            HStack(spacing: 0) {
                ForEach(
                    Array(composition.segments.enumerated()),
                    id: \.element.id
                ) { _, segment in
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
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                }

                Text("Other")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
            }
            .offset(y: 11)
        }
        .accessibilityHidden(true)
    }

    private func bezierLeaderPath(
        fromX sourceX: CGFloat,
        toX targetX: CGFloat
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: sourceX, y: 0))
        path.addCurve(
            to: CGPoint(x: targetX, y: 8),
            control1: CGPoint(x: sourceX, y: 5.5),
            control2: CGPoint(x: targetX, y: 2.5)
        )
        return path
    }

    private func segmentCenterX(
        at index: Int,
        usableWidth: CGFloat
    ) -> CGFloat {
        let precedingShare = composition.segments[..<index]
            .reduce(CGFloat.zero) {
                $0 + CGFloat($1.shareOfInstalledRAM)
            }
        let segment = composition.segments[index]
        return usableWidth
            * (
                precedingShare
                    + CGFloat(segment.shareOfInstalledRAM) / 2
            )
            + CGFloat(index)
    }

    private func remainderCenterX(
        usableWidth: CGFloat
    ) -> CGFloat {
        let attributedShare = composition.segments
            .reduce(CGFloat.zero) {
                $0 + CGFloat($1.shareOfInstalledRAM)
            }
        return usableWidth
            * (
                attributedShare
                    + CGFloat(composition.remainderShare) / 2
            )
            + CGFloat(composition.segments.count)
    }

    private func labelCenterX(
        at index: Int,
        width: CGFloat,
        itemCount: Int
    ) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        return width
            * (CGFloat(index) + 0.5)
            / CGFloat(itemCount)
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
