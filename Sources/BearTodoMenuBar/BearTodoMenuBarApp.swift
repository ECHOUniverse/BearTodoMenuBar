import SwiftUI

@main
struct BearTodoMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let accessGranted = BearBookmarkManager.shared.startAccessing()
        if !accessGranted {
            print("Warning: Bear database security-scoped resource access not granted")
        }

        menuBarController = MenuBarController()
        menuBarController?.onOpenSettings = { [weak self] in
            self?.showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        BearBookmarkManager.shared.stopAccessing()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        XCallbackClient.shared.receive(urls: urls)
    }

    private func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView(onClose: { [weak self] in
            self?.settingsWindow?.close()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settings
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
