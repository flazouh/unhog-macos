import AppKit
import SwiftUI

private struct CulpritReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var culpritReduceMotion: Bool {
        get { self[CulpritReduceMotionKey.self] }
        set { self[CulpritReduceMotionKey.self] = newValue }
    }
}

enum CulpritTheme {
    static let popoverWidth: CGFloat = 372
    static let popoverHeight: CGFloat = 500
    static let cornerRadius: CGFloat = 14
    static let compactRadius: CGFloat = 9
    static let pagePadding: CGFloat = 16

    static let surface = Color.primary.opacity(0.055)
    static let surfaceHover = Color.primary.opacity(0.085)
    static let subtleText = Color.secondary.opacity(0.86)
    static let attention = Color(red: 0.84, green: 0.48, blue: 0.12)
    static let destructive = Color(red: 0.82, green: 0.25, blue: 0.22)
    static let remainder = Color.primary.opacity(0.11)

    static func appColor(for name: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.16, green: 0.68, blue: 0.60),
            Color(red: 0.38, green: 0.51, blue: 0.91),
            Color(red: 0.22, green: 0.72, blue: 0.78),
            Color(red: 0.57, green: 0.43, blue: 0.88),
            Color(red: 0.35, green: 0.70, blue: 0.42),
            Color(red: 0.25, green: 0.58, blue: 0.91),
            Color(red: 0.32, green: 0.76, blue: 0.67),
            Color(red: 0.74, green: 0.43, blue: 0.78),
            Color(red: 0.48, green: 0.40, blue: 0.88),
            Color(red: 0.20, green: 0.63, blue: 0.88),
            Color(red: 0.16, green: 0.72, blue: 0.68),
            Color(red: 0.61, green: 0.52, blue: 0.91),
            Color(red: 0.27, green: 0.72, blue: 0.55),
            Color(red: 0.48, green: 0.58, blue: 0.92),
            Color(red: 0.73, green: 0.38, blue: 0.74),
            Color(red: 0.31, green: 0.66, blue: 0.92)
        ]
        let value = name.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1.value)) &* 1_099_511_628_211
        }
        return palette[Int(value % UInt64(palette.count))]
    }
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
            CulpritTheme.destructive
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
