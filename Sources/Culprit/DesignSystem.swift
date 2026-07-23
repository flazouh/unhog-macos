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
    static let energy = Color(
        red: 1,
        green: 141 / 255,
        blue: 34 / 255
    )
    static let destructive = Color(
        red: 1,
        green: 92 / 255,
        blue: 89 / 255
    )
    static let cpu = Color(
        red: 74 / 255,
        green: 207 / 255,
        blue: 1
    )
    static let ram = Color(
        red: 151 / 255,
        green: 88 / 255,
        blue: 1
    )
    static let selection = Color(
        red: 1,
        green: 120 / 255,
        blue: 247 / 255
    )
    static let attention = destructive
    static let remainder = Color.primary.opacity(0.11)

    static let motionEnter = Animation.timingCurve(
        0.23,
        1,
        0.32,
        1,
        duration: 0.20
    )
    static let motionMove = Animation.timingCurve(
        0.77,
        0,
        0.175,
        1,
        duration: 0.28
    )
    static let motionFade = Animation.easeOut(duration: 0.20)

    static func dataColor(at index: Int) -> Color {
        let colors = [ram, cpu, energy, selection]
        return colors[index % colors.count]
    }

    static func identityColor(for name: String) -> Color {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in name.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return dataColor(at: Int(hash % 4))
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
