import Foundation

public struct MemoryChipLayoutItem: Hashable, Sendable {
    public let id: Int
    public let preferredCenter: Double
    public let width: Double
    public let isFocused: Bool

    public init(
        id: Int,
        preferredCenter: Double,
        width: Double,
        isFocused: Bool
    ) {
        self.id = id
        self.preferredCenter = preferredCenter
        self.width = max(0, width)
        self.isFocused = isFocused
    }
}

public struct MemoryChipPlacement: Hashable, Sendable {
    public let id: Int
    public let preferredCenter: Double
    public let center: Double
    public let width: Double

    public var minimumX: Double {
        center - width / 2
    }

    public var maximumX: Double {
        center + width / 2
    }

    public var displacement: Double {
        abs(center - preferredCenter)
    }
}

public enum MemoryChipLayout {
    public static func place(
        _ items: [MemoryChipLayoutItem],
        availableWidth: Double,
        minimumGap: Double = 8
    ) -> [MemoryChipPlacement] {
        guard !items.isEmpty else { return [] }

        let availableWidth = max(0, availableWidth)
        let minimumGap = max(0, minimumGap)
        let focusedIndex = items.firstIndex(where: \.isFocused)
        var centers = items.map {
            clampedCenter(
                $0.preferredCenter,
                itemWidth: $0.width,
                availableWidth: availableWidth
            )
        }

        if let focusedIndex {
            placeLeftSide(
                items: items,
                centers: &centers,
                focusedIndex: focusedIndex,
                availableWidth: availableWidth,
                minimumGap: minimumGap
            )
            placeRightSide(
                items: items,
                centers: &centers,
                focusedIndex: focusedIndex,
                availableWidth: availableWidth,
                minimumGap: minimumGap
            )

            if !isValid(
                items: items,
                centers: centers,
                availableWidth: availableWidth,
                minimumGap: minimumGap
            ) {
                centers = items.map {
                    clampedCenter(
                        $0.preferredCenter,
                        itemWidth: $0.width,
                        availableWidth: availableWidth
                    )
                }
                placeUnanchored(
                    items: items,
                    centers: &centers,
                    availableWidth: availableWidth,
                    minimumGap: minimumGap
                )
            }
        } else {
            placeUnanchored(
                items: items,
                centers: &centers,
                availableWidth: availableWidth,
                minimumGap: minimumGap
            )
        }

        return zip(items, centers).map { item, center in
            MemoryChipPlacement(
                id: item.id,
                preferredCenter: item.preferredCenter,
                center: center,
                width: item.width
            )
        }
    }

    private static func isValid(
        items: [MemoryChipLayoutItem],
        centers: [Double],
        availableWidth: Double,
        minimumGap: Double
    ) -> Bool {
        guard
            let firstItem = items.first,
            let firstCenter = centers.first,
            let lastItem = items.last,
            let lastCenter = centers.last,
            firstCenter - firstItem.width / 2 >= 0,
            lastCenter + lastItem.width / 2 <= availableWidth
        else {
            return false
        }

        for index in items.indices.dropFirst() {
            let previousIndex = index - 1
            let previousMaximum = centers[previousIndex]
                + items[previousIndex].width / 2
            let currentMinimum = centers[index]
                - items[index].width / 2
            if previousMaximum + minimumGap > currentMinimum {
                return false
            }
        }

        return true
    }

    private static func placeLeftSide(
        items: [MemoryChipLayoutItem],
        centers: inout [Double],
        focusedIndex: Int,
        availableWidth: Double,
        minimumGap: Double
    ) {
        guard focusedIndex > items.startIndex else { return }

        for index in stride(
            from: focusedIndex - 1,
            through: items.startIndex,
            by: -1
        ) {
            let nextIndex = index + 1
            let largestCenter = centers[nextIndex]
                - items[nextIndex].width / 2
                - minimumGap
                - items[index].width / 2
            centers[index] = min(centers[index], largestCenter)
        }

        let leftOverflow = -(
            centers[items.startIndex] - items[items.startIndex].width / 2
        )
        guard leftOverflow > 0 else { return }

        for index in items.startIndex..<focusedIndex {
            centers[index] += leftOverflow
        }
    }

    private static func placeRightSide(
        items: [MemoryChipLayoutItem],
        centers: inout [Double],
        focusedIndex: Int,
        availableWidth: Double,
        minimumGap: Double
    ) {
        guard focusedIndex < items.index(before: items.endIndex) else { return }

        for index in (focusedIndex + 1)..<items.endIndex {
            let previousIndex = index - 1
            let smallestCenter = centers[previousIndex]
                + items[previousIndex].width / 2
                + minimumGap
                + items[index].width / 2
            centers[index] = max(centers[index], smallestCenter)
        }

        let lastIndex = items.index(before: items.endIndex)
        let rightOverflow = centers[lastIndex]
            + items[lastIndex].width / 2
            - availableWidth
        guard rightOverflow > 0 else { return }

        for index in (focusedIndex + 1)..<items.endIndex {
            centers[index] -= rightOverflow
        }
    }

    private static func placeUnanchored(
        items: [MemoryChipLayoutItem],
        centers: inout [Double],
        availableWidth: Double,
        minimumGap: Double
    ) {
        guard items.count > 1 else { return }

        for index in items.index(after: items.startIndex)..<items.endIndex {
            let previousIndex = index - 1
            let smallestCenter = centers[previousIndex]
                + items[previousIndex].width / 2
                + minimumGap
                + items[index].width / 2
            centers[index] = max(centers[index], smallestCenter)
        }

        let lastIndex = items.index(before: items.endIndex)
        centers[lastIndex] = min(
            centers[lastIndex],
            availableWidth - items[lastIndex].width / 2
        )

        for index in stride(
            from: lastIndex - 1,
            through: items.startIndex,
            by: -1
        ) {
            let nextIndex = index + 1
            let largestCenter = centers[nextIndex]
                - items[nextIndex].width / 2
                - minimumGap
                - items[index].width / 2
            centers[index] = min(centers[index], largestCenter)
        }
    }

    private static func clampedCenter(
        _ center: Double,
        itemWidth: Double,
        availableWidth: Double
    ) -> Double {
        let halfWidth = min(itemWidth, availableWidth) / 2
        return min(
            max(center, halfWidth),
            max(halfWidth, availableWidth - halfWidth)
        )
    }
}
