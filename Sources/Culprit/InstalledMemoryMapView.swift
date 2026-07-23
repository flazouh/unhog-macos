import AppKit
import CulpritCore
import SwiftUI

struct InstalledMemoryMapView: View {
    let composition: MemoryComposition
    let focusedGroupID: ProcessGroupID?

    @Environment(\.culpritReduceMotion) private var reduceMotion
    @State private var revealed = false

    private let barHeight: CGFloat = 18
    private let leaderHeight: CGFloat = 10
    private let chipHeight: CGFloat = 16
    private let segmentSpacing: CGFloat = 1
    private let chipGap: CGFloat = 8

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
                memoryChart(width: proxy.size.width)
            }
            .frame(height: barHeight + leaderHeight + chipHeight)
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

    private func memoryChart(
        width: CGFloat
    ) -> some View {
        let geometry = chartGeometry(width: width)
        let chips = chipModels(
            for: geometry.segments,
            availableWidth: width
        )

        return ZStack(alignment: .topLeading) {
            memoryBar(geometry: geometry, width: width)

            ForEach(chips) { chip in
                if chip.id == 0
                    || chip.isFocused
                    || chip.placement.displacement > 6
                {
                    leader(for: chip)
                        .trim(from: 0, to: revealed ? 1 : 0)
                        .stroke(
                            CulpritTheme.identityColor(
                                for: chip.segment.group.displayName
                            ),
                            style: StrokeStyle(
                                lineWidth: 1.35,
                                lineCap: .round
                            )
                        )
                }
            }

            ForEach(chips) { chip in
                appChip(chip)
                    .frame(
                        width: chip.width,
                        height: chipHeight,
                        alignment: .leading
                    )
                    .position(
                        x: revealed
                            ? chip.placement.center
                            : chip.preferredCenter,
                        y: barHeight + leaderHeight + chipHeight / 2
                    )
                    .opacity(revealed ? 1 : 0)
            }
        }
        .animation(
            reduceMotion ? nil : CulpritTheme.motionEnter,
            value: revealed
        )
    }

    private func memoryBar(
        geometry: ChartGeometry,
        width: CGFloat
    ) -> some View {
        HStack(spacing: segmentSpacing) {
            ForEach(geometry.segments) { item in
                memorySegment(item)
                    .frame(width: item.width)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(item.segment.group.displayName), "
                            + MetricFormatting.memory(item.segment.bytes)
                            + (
                                item.segment.group.id == focusedGroupID
                                    ? ", current issue"
                                    : ""
                            )
                    )
            }

            remainderSegment(width: geometry.remainderWidth)
                .frame(width: geometry.remainderWidth)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "macOS, other apps, and unused memory, "
                        + MetricFormatting.memory(
                            composition.remainderBytes
                        )
                )
        }
        .frame(width: width, height: barHeight)
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

    private func memorySegment(
        _ item: SegmentGeometry
    ) -> some View {
        ZStack {
            CulpritTheme.identityColor(
                for: item.segment.group.displayName
            )
            .opacity(segmentOpacity(for: item.segment))

            if memoryValueFits(
                bytes: item.segment.bytes,
                width: item.width
            ) {
                memoryValue(item.segment.bytes)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 1)
            }
        }
    }

    private func remainderSegment(
        width: CGFloat
    ) -> some View {
        ZStack {
            CulpritTheme.remainder

            if remainderValueFits(width: width) {
                Text(
                    "Other · \(MetricFormatting.memory(composition.remainderBytes))"
                )
                .font(.system(size: 7.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 3)
            }
        }
    }

    private func appChip(
        _ chip: MemoryChipModel
    ) -> some View {
        HStack(spacing: 3) {
            ProcessIconView(
                group: chip.segment.group,
                size: 12
            )

            Text(chip.label)
                .font(
                    .system(
                        size: 9,
                        weight: chip.isFocused
                            ? .semibold
                            : .medium
                    )
                )
                .foregroundStyle(
                    chip.isFocused
                        ? .primary
                        : .secondary
                )
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityHidden(true)
    }

    private func leader(
        for chip: MemoryChipModel
    ) -> Path {
        let start = CGPoint(
            x: chip.preferredCenter,
            y: barHeight
        )
        let end = CGPoint(
            x: chip.placement.center,
            y: barHeight + leaderHeight
        )
        let horizontalDistance = end.x - start.x
        let subtleBow: CGFloat = abs(horizontalDistance) < 8 ? 0 : 1

        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(
                x: start.x + horizontalDistance / 3 + subtleBow,
                y: barHeight + leaderHeight / 3
            ),
            control2: CGPoint(
                x: start.x + horizontalDistance * 2 / 3 + subtleBow,
                y: barHeight + leaderHeight * 2 / 3
            )
        )
        return path
    }

    private func chartGeometry(
        width: CGFloat
    ) -> ChartGeometry {
        let itemCount = composition.segments.count + 1
        let totalSpacing = segmentSpacing
            * CGFloat(max(0, itemCount - 1))
        let usableWidth = max(0, width - totalSpacing)
        var cursor: CGFloat = 0

        let segments = composition.segments.map { segment in
            let segmentWidth = usableWidth
                * segment.shareOfInstalledRAM
            let item = SegmentGeometry(
                segment: segment,
                minimumX: cursor,
                width: segmentWidth
            )
            cursor += segmentWidth + segmentSpacing
            return item
        }

        return ChartGeometry(
            segments: segments,
            remainderWidth: usableWidth * composition.remainderShare
        )
    }

    private func chipModels(
        for segments: [SegmentGeometry],
        availableWidth: CGFloat
    ) -> [MemoryChipModel] {
        guard !segments.isEmpty else { return [] }

        let totalGaps = chipGap * CGFloat(max(0, segments.count - 1))
        let widthPerChip = max(
            0,
            (availableWidth - totalGaps) / CGFloat(segments.count)
        )
        let maximumChipWidth = min(120, widthPerChip)

        let drafts = segments.enumerated().map { index, item in
            let label = item.segment.group.displayName
            let focused = item.segment.group.id == focusedGroupID

            return MemoryChipDraft(
                id: index,
                segment: item.segment,
                preferredCenter: item.midX,
                label: label,
                width: min(
                    maximumChipWidth,
                    measuredChipWidth(
                        label: label,
                        isFocused: focused
                    )
                ),
                isFocused: focused
            )
        }

        let placements = MemoryChipLayout.place(
            drafts.map {
                MemoryChipLayoutItem(
                    id: $0.id,
                    preferredCenter: Double($0.preferredCenter),
                    width: Double($0.width),
                    isFocused: $0.isFocused
                )
            },
            availableWidth: Double(availableWidth),
            minimumGap: Double(chipGap)
        )
        let placementsByID = Dictionary(
            uniqueKeysWithValues: placements.map { ($0.id, $0) }
        )

        return drafts.compactMap { draft in
            guard let placement = placementsByID[draft.id] else {
                return nil
            }
            return MemoryChipModel(
                id: draft.id,
                segment: draft.segment,
                preferredCenter: draft.preferredCenter,
                label: draft.label,
                width: draft.width,
                isFocused: draft.isFocused,
                placement: placement
            )
        }
    }

    private func remainderValueFits(
        width: CGFloat
    ) -> Bool {
        let label = "Other · "
            + MetricFormatting.memory(composition.remainderBytes)
        return measuredTextWidth(
            label,
            font: .systemFont(
                ofSize: 7.5,
                weight: .medium
            )
        ) + 6 <= width
    }

    private func memoryValueFits(
        bytes: UInt64,
        width: CGFloat
    ) -> Bool {
        guard width >= 24 else { return false }

        return measuredTextWidth(
            MetricFormatting.memory(bytes),
            font: .systemFont(
                ofSize: 7.5 * 0.72,
                weight: .semibold
            )
        ) + 2 <= width
    }

    private func measuredChipWidth(
        label: String,
        isFocused: Bool
    ) -> CGFloat {
        measuredTextWidth(
            label,
            font: .systemFont(
                ofSize: 9,
                weight: isFocused ? .semibold : .medium
            )
        ) + 15
    }

    private func measuredTextWidth(
        _ text: String,
        font: NSFont
    ) -> CGFloat {
        ceil(
            (text as NSString).size(
                withAttributes: [.font: font]
            ).width
        )
    }

    private func segmentOpacity(
        for segment: AppMemorySegment
    ) -> Double {
        guard let focusedGroupID else { return 1 }
        return segment.group.id == focusedGroupID ? 1 : 0.42
    }

    private func memoryValue(
        _ bytes: UInt64
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
            .minimumScaleFactor(0.72)
            .foregroundStyle(Color.black.opacity(0.88))
            .lineLimit(1)
    }
}

private struct ChartGeometry {
    let segments: [SegmentGeometry]
    let remainderWidth: CGFloat
}

private struct SegmentGeometry: Identifiable {
    var id: ProcessGroupID {
        segment.id
    }

    let segment: AppMemorySegment
    let minimumX: CGFloat
    let width: CGFloat

    var midX: CGFloat {
        minimumX + width / 2
    }
}

private struct MemoryChipDraft {
    let id: Int
    let segment: AppMemorySegment
    let preferredCenter: CGFloat
    let label: String
    let width: CGFloat
    let isFocused: Bool
}

private struct MemoryChipModel: Identifiable {
    let id: Int
    let segment: AppMemorySegment
    let preferredCenter: CGFloat
    let label: String
    let width: CGFloat
    let isFocused: Bool
    let placement: MemoryChipPlacement
}
