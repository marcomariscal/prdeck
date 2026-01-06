import AppKit
import PRDeckFeature
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dataController: DataController?
    private var windowController: WindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.regular)
        installMenu()

        let dataController = DataController()
        self.dataController = dataController

        let rootView = ContentView(dataController: dataController)
        let windowController = WindowController(rootView: rootView)
        self.windowController = windowController

        windowController.showWindow(nil)
        dataController.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = nil
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Quit PRDeck",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let viewMenuItem = NSMenuItem()
        viewMenuItem.title = "View"
        mainMenu.addItem(viewMenuItem)

        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let zoomIn = NSMenuItem(title: "Zoom In", action: #selector(zoomIn(_:)), keyEquivalent: "=")
        zoomIn.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomIn)

        let zoomOut = NSMenuItem(title: "Zoom Out", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        zoomOut.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomOut)

        let actualSize = NSMenuItem(title: "Actual Size", action: #selector(zoomReset(_:)), keyEquivalent: "0")
        actualSize.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(actualSize)

        NSApp.mainMenu = mainMenu
    }

    @objc private func zoomIn(_ sender: Any?) {
        bumpZoomStep(by: 1)
    }

    @objc private func openSettings(_ sender: Any?) {
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: sender) { return }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: sender)
    }

    @objc private func zoomOut(_ sender: Any?) {
        bumpZoomStep(by: -1)
    }

    @objc private func zoomReset(_ sender: Any?) {
        UserDefaults.standard.set(0, forKey: PRDeckDefaultsKey.zoomStep)
    }

    private func bumpZoomStep(by delta: Int) {
        let current = UserDefaults.standard.integer(forKey: PRDeckDefaultsKey.zoomStep)
        UserDefaults.standard.set(max(-3, min(6, current + delta)), forKey: PRDeckDefaultsKey.zoomStep)
    }
}
