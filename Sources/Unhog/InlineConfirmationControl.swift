import SwiftUI

struct InlineConfirmationControl: View {
    let confirmTitle: String
    let confirmAccessibilityLabel: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button("Cancel", action: onCancel)
                .buttonStyle(
                    ConfirmationSegmentStyle(tone: .cancel)
                )
                .accessibilityHint("Keeps the workload running")

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1, height: 20)
                .accessibilityHidden(true)

            Button(confirmTitle, action: onConfirm)
                .buttonStyle(
                    ConfirmationSegmentStyle(tone: .confirm)
                )
                .accessibilityLabel(confirmAccessibilityLabel)
        }
        .background(UnhogTheme.surfaceHover)
        .clipShape(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
    }
}

private struct ConfirmationSegmentStyle: ButtonStyle {
    enum Tone {
        case cancel
        case confirm
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        ConfirmationSegmentBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            tone: tone
        )
    }
}

private struct ConfirmationSegmentBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let tone: ConfirmationSegmentStyle.Tone

    @Environment(\.unhogReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 13)
            .frame(minWidth: 64, minHeight: 34)
            .background(background)
            .contentShape(Rectangle())
            .scaleEffect(
                reduceMotion ? 1 : isPressed ? 0.97 : 1
            )
            .onHover { isHovered = $0 }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: isHovered
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.10),
                value: isPressed
            )
    }

    private var foreground: Color {
        switch tone {
        case .cancel:
            .primary
        case .confirm:
            .white
        }
    }

    private var background: Color {
        switch tone {
        case .cancel:
            isPressed || isHovered
                ? UnhogTheme.surfaceHover
                : .clear
        case .confirm:
            UnhogTheme.destructive.opacity(
                isPressed ? 0.76 : isHovered ? 0.88 : 1
            )
        }
    }
}
