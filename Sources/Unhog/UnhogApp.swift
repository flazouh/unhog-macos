import AppKit
import SwiftUI

@main
struct UnhogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore

    init() {
        let showsPreviewWindow =
            ProcessInfo.processInfo.environment["UNHOG_UI_PREVIEW"] == "1"
        let store = AppStore(actionsEnabled: !showsPreviewWindow)
        _store = StateObject(wrappedValue: store)
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

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .environment(
                    \.unhogReduceMotion,
                    store.shouldReduceMotion
                )
        } label: {
            let presentation = store.menuBarPresentation
            HStack(spacing: 4) {
                if presentation.symbolName == "circle" {
                    UnhogMenuBarMark()
                } else {
                    Image(systemName: presentation.symbolName)
                }
                if presentation.compactLabel != nil,
                   let signature = store.menuBarDrainSignature {
                    MenuBarSignatureView(signature: signature)
                } else if let label = presentation.compactLabel {
                    Text(label)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
                .environment(
                    \.unhogReduceMotion,
                    store.shouldReduceMotion
                )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showsPreviewWindow =
            ProcessInfo.processInfo.environment["UNHOG_UI_PREVIEW"] == "1"
        NSApp.setActivationPolicy(showsPreviewWindow ? .regular : .accessory)
        if showsPreviewWindow {
            NSApp.activate(ignoringOtherApps: true)
            PreviewSupport.present()
        }
    }
}
