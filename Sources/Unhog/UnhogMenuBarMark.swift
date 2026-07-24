import AppKit
import SwiftUI

@MainActor
struct UnhogMenuBarMark: View {
    var body: some View {
        Group {
            if let image = UnhogMenuBarMarkImage.image {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: "circle")
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

@MainActor
private enum UnhogMenuBarMarkImage {
    static let image: NSImage? = {
        guard let url = UnhogResourceBundle.bundle?.url(
            forResource: "menubar-mono",
            withExtension: "svg"
        ), let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        return image
    }()
}
