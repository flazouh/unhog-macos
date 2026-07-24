import AppKit
import SwiftUI
import UnhogCore

struct UsageProviderMark: View {
    let provider: UsageProvider
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UsageProviderAssets.image(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: size * 0.55, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.displayName)
    }
}

@MainActor
private enum UsageProviderAssets {
    static let codex = load("codex")
    static let claude = load("claude")

    static func image(for provider: UsageProvider) -> NSImage? {
        switch provider {
        case .claude:
            claude
        case .codex:
            codex
        }
    }

    private static func load(_ name: String) -> NSImage? {
        guard let bundle = UnhogResourceBundle.bundle,
            let url = bundle.url(
                forResource: name,
                withExtension: "svg",
                subdirectory: "UsageProviders"
            )
                ?? bundle.url(
                    forResource: name,
                    withExtension: "svg"
                )
        else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
