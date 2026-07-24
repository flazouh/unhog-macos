import SwiftUI

enum PopoverSection: String, CaseIterable, Identifiable {
    case activity
    case usage
    case storage

    var id: Self { self }

    var title: String {
        switch self {
        case .activity:
            "Activity"
        case .usage:
            "Usage"
        case .storage:
            "Storage"
        }
    }

    var symbolName: String {
        switch self {
        case .activity:
            "waveform.path.ecg"
        case .usage:
            "chart.bar.xaxis"
        case .storage:
            "internaldrive"
        }
    }
}

struct PopoverSectionPicker: View {
    @Binding var selection: PopoverSection

    @Environment(\.unhogReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PopoverSection.allCases) { section in
                Button {
                    withAnimation(
                        reduceMotion ? nil : UnhogTheme.motionMove
                    ) {
                        selection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(
                        selection == section ? .primary : .secondary
                    )
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background {
                        if selection == section {
                            RoundedRectangle(
                                cornerRadius: 7,
                                style: .continuous
                            )
                            .fill(UnhogTheme.surfaceHover)
                            .matchedGeometryEffect(
                                id: "section-selection",
                                in: selectionNamespace
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    selection == section ? .isSelected : []
                )
            }
        }
        .padding(3)
        .background(UnhogTheme.surface.opacity(0.7))
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.compactRadius,
                style: .continuous
            )
        )
    }
}
