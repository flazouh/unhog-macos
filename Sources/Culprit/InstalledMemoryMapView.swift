import CulpritCore
import SwiftUI

struct InstalledMemoryMapView: View {
    let composition: MemoryComposition
    let selectedGroupID: ProcessGroupID?
    let onSelect: (ProcessGroupID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Share of installed RAM")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(MetricFormatting.memory(composition.installedBytes)) installed")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(composition.segments) { segment in
                        Button {
                            onSelect(segment.id)
                        } label: {
                            CulpritTheme.appColor(for: segment.group.displayName)
                                .opacity(
                                    selectedGroupID == nil
                                        || selectedGroupID == segment.id ? 1 : 0.48
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: proxy.size.width
                                * segment.shareOfInstalledRAM
                        )
                        .accessibilityLabel(
                            "\(segment.group.displayName), "
                                + "\(MetricFormatting.ramShare(segment.shareOfInstalledRAM)) "
                                + "of installed RAM"
                        )
                    }

                    CulpritTheme.remainder
                        .frame(
                            width: proxy.size.width
                                * composition.remainderShare
                        )
                        .accessibilityLabel(
                            "macOS, other apps, and free memory, "
                                + "\(MetricFormatting.ramShare(composition.remainderShare))"
                        )
                }
                .clipShape(Capsule())
            }
            .frame(height: 11)

            HStack(spacing: 10) {
                ForEach(composition.segments.prefix(3)) { segment in
                    legendItem(segment)
                }
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    Circle()
                        .fill(CulpritTheme.remainder)
                        .frame(width: 5, height: 5)
                    Text("macOS + rest")
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }

            Text(footnote)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private var footnote: String {
        if composition.hasOverlappingProcessTotals {
            return "Some process memory overlaps, so only full shares are shown."
        }
        return "Grey includes macOS, other processes and free memory."
    }

    private func legendItem(_ segment: AppMemorySegment) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(CulpritTheme.appColor(for: segment.group.displayName))
                .frame(width: 5, height: 5)
            Text(segment.group.displayName)
                .lineLimit(1)
            Text(MetricFormatting.ramShare(segment.shareOfInstalledRAM))
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 9))
    }
}
