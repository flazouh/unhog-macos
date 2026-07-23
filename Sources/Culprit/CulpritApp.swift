import AppKit
import SwiftUI

@main
struct CulpritApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore

    init() {
        let showsPreviewWindow =
            ProcessInfo.processInfo.environment["CULPRIT_UI_PREVIEW"] == "1"
        let store = AppStore()
        if showsPreviewWindow {
            PreviewSupport.store = store
        }
        _store = StateObject(wrappedValue: store)
        store.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            Label("Culprit", systemImage: store.menuBarSymbol)
                .accessibilityLabel(store.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showsPreviewWindow =
            ProcessInfo.processInfo.environment["CULPRIT_UI_PREVIEW"] == "1"
        NSApp.setActivationPolicy(showsPreviewWindow ? .regular : .accessory)
        if showsPreviewWindow {
            NSApp.activate(ignoringOtherApps: true)
            PreviewSupport.present()
        }
    }
}
