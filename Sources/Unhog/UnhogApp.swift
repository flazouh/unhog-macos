import AppKit
import SwiftUI

@main
struct UnhogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRoot(store: appDelegate.store)
        }
    }
}

@MainActor
private struct SettingsRoot: View {
    @ObservedObject var store: AppStore

    var body: some View {
        SettingsView(store: store)
            .environment(
                \.unhogReduceMotion,
                store.shouldReduceMotion
            )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: AppStore
    private var menuBarWidgetController: MenuBarWidgetController?

    override init() {
        let showsPreviewWindow =
            ProcessInfo.processInfo.environment["UNHOG_UI_PREVIEW"] == "1"
        store = AppStore(actionsEnabled: !showsPreviewWindow)
        super.init()

        if showsPreviewWindow {
            PreviewSupport.store = store
            PreviewSupport.applyFixtureIfRequested(to: store)
        }
        if ProcessInfo.processInfo.environment[
            "UNHOG_UI_PREVIEW_STATE"
        ] == nil {
            store.start()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showsPreviewWindow =
            ProcessInfo.processInfo.environment["UNHOG_UI_PREVIEW"] == "1"
        NSApp.setActivationPolicy(showsPreviewWindow ? .regular : .accessory)
        if showsPreviewWindow {
            NSApp.activate(ignoringOtherApps: true)
            PreviewSupport.present()
        } else {
            menuBarWidgetController = MenuBarWidgetController(store: store)
        }
    }
}
