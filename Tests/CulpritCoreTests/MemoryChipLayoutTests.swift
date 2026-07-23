import Testing
@testable import CulpritCore

@Suite("Memory chip placement")
struct MemoryChipLayoutTests {
    @Test("Separated chips stay beneath their memory segments")
    func keepsNaturalPositions() {
        let placements = MemoryChipLayout.place(
            [
                .init(id: 0, preferredCenter: 50, width: 40, isFocused: false),
                .init(id: 1, preferredCenter: 150, width: 50, isFocused: true),
                .init(id: 2, preferredCenter: 260, width: 40, isFocused: false)
            ],
            availableWidth: 320
        )

        #expect(placements.map(\.center) == [50, 150, 260])
    }

    @Test("Colliding chips spread around the anchored focused app")
    func spreadsAroundFocus() {
        let placements = MemoryChipLayout.place(
            [
                .init(id: 0, preferredCenter: 120, width: 70, isFocused: false),
                .init(id: 1, preferredCenter: 150, width: 70, isFocused: true),
                .init(id: 2, preferredCenter: 180, width: 70, isFocused: false)
            ],
            availableWidth: 320,
            minimumGap: 8
        )

        #expect(placements.map(\.center) == [72, 150, 228])
        #expect(placements[1].displacement == 0)
    }

    @Test("A crowded row stays inside its available width")
    func avoidsRightEdgeOverflow() {
        let placements = MemoryChipLayout.place(
            [
                .init(id: 0, preferredCenter: 230, width: 60, isFocused: false),
                .init(id: 1, preferredCenter: 270, width: 60, isFocused: false),
                .init(id: 2, preferredCenter: 300, width: 60, isFocused: false)
            ],
            availableWidth: 320,
            minimumGap: 8
        )

        #expect(placements.map(\.center) == [154, 222, 290])
        #expect(placements.first!.minimumX >= 0)
        #expect(placements.last!.maximumX <= 320)
    }

    @Test("A focus too close to an edge yields before labels overlap")
    func movesAnInfeasibleFocus() {
        let placements = MemoryChipLayout.place(
            [
                .init(id: 0, preferredCenter: 20, width: 80, isFocused: false),
                .init(id: 1, preferredCenter: 70, width: 80, isFocused: true),
                .init(id: 2, preferredCenter: 120, width: 80, isFocused: false)
            ],
            availableWidth: 280,
            minimumGap: 8
        )

        #expect(placements[0].maximumX + 8 <= placements[1].minimumX)
        #expect(placements[1].maximumX + 8 <= placements[2].minimumX)
        #expect(placements.first!.minimumX >= 0)
        #expect(placements.last!.maximumX <= 280)
    }

    @Test("A focus too close to the right edge also yields")
    func movesAnInfeasibleRightFocus() {
        let placements = MemoryChipLayout.place(
            [
                .init(id: 0, preferredCenter: 160, width: 80, isFocused: false),
                .init(id: 1, preferredCenter: 210, width: 80, isFocused: true),
                .init(id: 2, preferredCenter: 260, width: 80, isFocused: false)
            ],
            availableWidth: 280,
            minimumGap: 8
        )

        #expect(placements[0].maximumX + 8 <= placements[1].minimumX)
        #expect(placements[1].maximumX + 8 <= placements[2].minimumX)
        #expect(placements.first!.minimumX >= 0)
        #expect(placements.last!.maximumX <= 280)
    }
}
