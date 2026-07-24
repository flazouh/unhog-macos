import AppKit
import SwiftUI
import UnhogCore

struct AgentProviderMark: View {
    let provider: AgentProvider
    let size: CGFloat
    var isWorking = false

    @Environment(\.unhogReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if provider == .claude, isWorking, !reduceMotion {
                ClaudeWorkingSpark(size: size)
            } else if let image = ProviderBrandAssets.image(
                for: provider
            ) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(
                    systemName: provider == .codex
                        ? "terminal"
                        : "sparkles"
                )
                .font(.system(size: size * 0.55, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(
            provider == .codex ? "Codex" : "Claude Code"
        )
    }
}

@MainActor
private enum ProviderBrandAssets {
    static let codex = load("codex")
    static let claude = load("claude-code")

    static func image(for provider: AgentProvider) -> NSImage? {
        provider == .codex ? codex : claude
    }

    private static func load(_ name: String) -> NSImage? {
        guard let bundle = UnhogResourceBundle.bundle else {
            return nil
        }

        // SwiftPM flattens processed resource folders in packaged bundles.
        // Keep the subdirectory lookup for development builds and fall back to
        // the flattened path used by the signed app.
        guard let url = bundle.url(
            forResource: name,
            withExtension: "svg",
            subdirectory: "Agents"
        ) ?? bundle.url(
            forResource: name,
            withExtension: "svg"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

private struct ClaudeWorkingSpark: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { context in
            let elapsed = context.date
                .timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 5.04)
            let frameIndex = Int(elapsed / 0.06) % 84

            if ClaudeWorkingSparkFrames.images.indices.contains(
                frameIndex
            ) {
                Image(
                    nsImage: ClaudeWorkingSparkFrames.images[frameIndex]
                )
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .foregroundStyle(ClaudeWorkingSparkFrames.color)
                .frame(width: size, height: size)
            } else {
                FallbackClaudeSparkFrame(
                    size: size,
                    phase: elapsed / 5.04
                )
            }
        }
    }
}

@MainActor
private enum ClaudeWorkingSparkFrames {
    static let color = Color(
        red: 217 / 255,
        green: 119 / 255,
        blue: 87 / 255
    )

    static let images: [NSImage] = {
        guard let bundle = UnhogResourceBundle.bundle,
              let url = bundle.url(
                forResource: "claude-working-spark",
                withExtension: "base64",
                subdirectory: "Agents"
              ) ?? bundle.url(
                forResource: "claude-working-spark",
                withExtension: "base64"
              ),
              let encoded = try? String(
                contentsOf: url,
                encoding: .utf8
              ),
              let data = Data(
                base64Encoded: encoded.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
              ),
              let sprite = NSImage(data: data),
              let image = sprite.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
              ) else {
            return []
        }

        let frameCount = 84
        let frameHeight = image.height / frameCount
        guard frameHeight > 0 else { return [] }

        return (0 ..< frameCount).compactMap { index in
            let rect = CGRect(
                x: 0,
                y: index * frameHeight,
                width: image.width,
                height: frameHeight
            )
            guard let frame = image.cropping(to: rect) else {
                return nil
            }
            return NSImage(
                cgImage: frame,
                size: NSSize(width: image.width, height: frameHeight)
            )
        }
    }()
}

private struct FallbackClaudeSparkFrame: View {
    let size: CGFloat
    let phase: Double

    var body: some View {
        ZStack {
            ForEach(0 ..< 12, id: \.self) { index in
                let angle = Double(index) * 30
                let wave = (
                    sin(
                        phase * .pi * 6
                            + Double(index) * 1.17
                    ) + 1
                ) / 2
                let length = size * (0.18 + wave * 0.18)

                Capsule()
                    .fill(ClaudeWorkingSparkFrames.color)
                    .frame(
                        width: max(1, size * 0.075),
                        height: length
                    )
                    .offset(y: -(size * 0.16 + length / 2))
                    .rotationEffect(.degrees(angle))
                    .opacity(0.42 + wave * 0.58)
            }
        }
        .rotationEffect(.degrees(phase * 120))
        .frame(width: size, height: size)
        .drawingGroup()
    }
}
