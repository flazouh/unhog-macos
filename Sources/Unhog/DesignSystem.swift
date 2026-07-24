import AppKit
import SwiftUI
import UnhogCore

private struct UnhogReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var unhogReduceMotion: Bool {
        get { self[UnhogReduceMotionKey.self] }
        set { self[UnhogReduceMotionKey.self] = newValue }
    }
}

enum UnhogTheme {
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
    static let healthy = Color(
        red: 21 / 255,
        green: 219 / 255,
        blue: 149 / 255
    )
    static let warning = Color(
        red: 251 / 255,
        green: 215 / 255,
        blue: 60 / 255
    )
    static let healthyForeground = adaptiveForeground(
        light: NSColor(
            srgbRed: 0,
            green: 122 / 255,
            blue: 83 / 255,
            alpha: 1
        ),
        dark: NSColor(
            srgbRed: 21 / 255,
            green: 219 / 255,
            blue: 149 / 255,
            alpha: 1
        )
    )
    static let warningForeground = adaptiveForeground(
        light: NSColor(
            srgbRed: 122 / 255,
            green: 88 / 255,
            blue: 0,
            alpha: 1
        ),
        dark: NSColor(
            srgbRed: 251 / 255,
            green: 215 / 255,
            blue: 60 / 255,
            alpha: 1
        )
    )
    static let attention = destructive
    static let remainder = Color.primary.opacity(0.11)

    private static let dataColors = [
        ram,
        cpu,
        energy,
        selection,
    ]

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
        dataColors[index % dataColors.count]
    }

    static func identityColor(for name: String) -> Color {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in name.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return dataColor(
            at: Int(hash % UInt64(dataColors.count))
        )
    }

    static func severityColor(
        for severity: ResourceSeverity
    ) -> Color {
        severity == .high ? attention : warning
    }

    static func severityForeground(
        for severity: ResourceSeverity
    ) -> Color {
        severity == .high ? attention : warningForeground
    }

    private static func adaptiveForeground(
        light: NSColor,
        dark: NSColor
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(
                    from: [.aqua, .darkAqua]
                ) == .darkAqua ? dark : light
            }
        )
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
            UnhogTheme.surfaceHover
        case .destructive:
            UnhogTheme.destructive
        }
    }
}

struct InlineActionStyle: ButtonStyle {
    var tone: Color = .secondary
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        InlineActionBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            tone: tone,
            compact: compact
        )
    }
}

private struct InlineActionBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let tone: Color
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.unhogReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        label
            .font(
                .system(
                    size: compact ? 9 : 12,
                    weight: .semibold
                )
            )
            .foregroundStyle(tone)
            .padding(.horizontal, compact ? 7 : 8)
            .frame(minHeight: compact ? 24 : 32)
            .background(background)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: compact ? 7 : 9,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.46)
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

    private var background: Color {
        guard isEnabled else {
            return UnhogTheme.surface.opacity(0.32)
        }
        if isPressed || isHovered {
            return UnhogTheme.surfaceHover
        }
        return UnhogTheme.surface.opacity(0.48)
    }
}

struct SoftSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(UnhogTheme.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: UnhogTheme.cornerRadius,
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
