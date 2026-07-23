import AppKit
import CulpritCore
import SwiftUI

struct ProcessIconView: View {
    let group: ProcessGroup
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let image = applicationIcon {
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
        .background(CulpritTheme.surfaceHover)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }

    private var applicationIcon: NSImage? {
        guard case .application = group.kind else { return nil }
        return NSRunningApplication(
            processIdentifier: group.id.rootPID
        )?.icon
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
