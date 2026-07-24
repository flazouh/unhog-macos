public enum MenuBarWidgetInteraction: Sendable {
    case escape
    case outsideApplication
    case ownWindow
    case statusItem
}

public struct MenuBarWidgetDismissalPolicy: Sendable {
    public init() {}

    public func shouldDismiss(
        for interaction: MenuBarWidgetInteraction
    ) -> Bool {
        switch interaction {
        case .escape, .outsideApplication:
            true
        case .ownWindow, .statusItem:
            false
        }
    }
}
