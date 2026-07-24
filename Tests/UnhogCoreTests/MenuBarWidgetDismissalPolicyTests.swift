import Testing
@testable import UnhogCore

struct MenuBarWidgetDismissalPolicyTests {
    private let policy = MenuBarWidgetDismissalPolicy()

    @Test
    func openingAnotherUnhogWindowKeepsWidgetOpen() {
        #expect(policy.shouldDismiss(for: .ownWindow) == false)
    }

    @Test
    func escapeAndOutsideApplicationDismissWidget() {
        #expect(policy.shouldDismiss(for: .escape))
        #expect(policy.shouldDismiss(for: .outsideApplication))
    }

    @Test
    func statusItemControlsWidgetDirectly() {
        #expect(policy.shouldDismiss(for: .statusItem) == false)
    }
}
