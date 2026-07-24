import AppKit
import UnhogCore
import SwiftUI

struct ProcessIconView: View {
    let group: ProcessGroup
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let toolIcon {
                knownToolMark(toolIcon)
            } else if let image = applicationIcon {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var applicationIcon: NSImage? {
        guard case .application = group.kind else { return nil }
        return NSRunningApplication(
            processIdentifier: group.id.rootPID
        )?.icon
    }

    private var toolIcon: KnownToolIcon? {
        KnownToolIconResolver.icon(for: group)
    }

    @ViewBuilder
    private func knownToolMark(_ icon: KnownToolIcon) -> some View {
        if icon == .playwright {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(Color(red: 0.18, green: 0.64, blue: 0.36))
        } else if let image = bundledImage(for: icon) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(markColor(for: icon))
                .padding(size * 0.2)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func bundledImage(for icon: KnownToolIcon) -> NSImage? {
        guard let assetName = icon.bundledAssetName else { return nil }
        return ToolIconImageCache.shared.image(named: assetName)
    }

    private func markColor(for icon: KnownToolIcon) -> Color {
        switch icon {
        case .bun, .nx:
            .primary
        case .node:
            Color(red: 0.37, green: 0.63, blue: 0.31)
        case .typeScript:
            Color(red: 0.19, green: 0.47, blue: 0.78)
        case .playwright:
            Color(red: 0.18, green: 0.64, blue: 0.36)
        }
    }

    private var fallbackSymbol: String {
        switch group.kind {
        case .playwright:
            "globe"
        case .typeScript:
            "curlybraces"
        case .nx:
            "square.stack.3d.up"
        case .application:
            "terminal"
        }
    }
}

@MainActor
private final class ToolIconImageCache {
    static let shared = ToolIconImageCache()

    private let images = NSCache<NSString, NSImage>()

    func image(named name: String) -> NSImage? {
        let key = name as NSString
        if let cached = images.object(forKey: key) {
            return cached
        }
        guard let url = UnhogResourceBundle.bundle?.url(
            forResource: name,
            withExtension: "svg"
        ), let image = NSImage(contentsOf: url) else {
            return nil
        }
        images.setObject(image, forKey: key)
        return image
    }
}
