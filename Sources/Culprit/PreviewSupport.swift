import AppKit
import SwiftUI

@MainActor
enum PreviewSupport {
    static var store: AppStore?
    private static var window: NSWindow?

    static func present() {
        guard window == nil, let store else { return }

        let controller = NSHostingController(rootView: PopoverView(store: store))
        let previewWindow = NSWindow(contentViewController: controller)
        previewWindow.title = "Culprit Preview"
        previewWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        previewWindow.titlebarAppearsTransparent = true
        previewWindow.isMovableByWindowBackground = true
        previewWindow.setContentSize(
            NSSize(width: CulpritTheme.popoverWidth, height: 560)
        )
        previewWindow.center()
        previewWindow.makeKeyAndOrderFront(nil)
        window = previewWindow
    }
}
