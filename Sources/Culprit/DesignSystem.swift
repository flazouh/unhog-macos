import AppKit
import SwiftUI

enum CulpritTheme {
    static let popoverWidth: CGFloat = 390
    static let cornerRadius: CGFloat = 16
    static let compactRadius: CGFloat = 11
    static let pagePadding: CGFloat = 18

    static let surface = Color.primary.opacity(0.055)
    static let surfaceHover = Color.primary.opacity(0.085)
    static let subtleText = Color.secondary.opacity(0.86)
    static let warning = Color(red: 0.86, green: 0.51, blue: 0.13)
    static let critical = Color(red: 0.82, green: 0.25, blue: 0.22)
}

struct BorderlessActionStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case destructive
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(background.opacity(configuration.isPressed ? 0.76 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .primary, .destructive:
            Color(nsColor: .windowBackgroundColor)
        case .secondary:
            .primary
        }
    }

    private var background: Color {
        switch tone {
        case .primary:
            .primary
        case .secondary:
            CulpritTheme.surfaceHover
        case .destructive:
            CulpritTheme.critical
        }
    }
}

struct SoftSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(CulpritTheme.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: CulpritTheme.cornerRadius,
                    style: .continuous
                )
            )
    }
}

extension View {
    func tabularMetric() -> some View {
        font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
    }
}
