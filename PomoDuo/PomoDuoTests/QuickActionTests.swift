import UIKit
import Testing

@testable import PomoDuo

@MainActor
struct QuickActionTests {
    @Test func shortcutItemTypesMatchEnumCases() {
        let types = Set(QuickAction.allCases.map(\.shortcutItem.type))
        #expect(types == Set(QuickAction.allCases.map(\.rawValue)))
    }

    @Test func managerHandlesRecognizedShortcut() {
        let manager = QuickActionManager()

        let handled = manager.handle(QuickAction.reportBug.shortcutItem)

        #expect(handled)
        #expect(manager.consumePendingAction() == .reportBug)
        #expect(manager.consumePendingAction() == nil)
    }

    @Test func managerRejectsUnknownShortcut() {
        let manager = QuickActionManager()
        let unknownItem = UIApplicationShortcutItem(
            type: "com.pomoduo.invalid.quickAction",
            localizedTitle: "Unknown"
        )

        let handled = manager.handle(unknownItem)

        #expect(handled == false)
        #expect(manager.consumePendingAction() == nil)
    }
}
