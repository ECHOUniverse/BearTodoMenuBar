import SwiftUI
import ServiceManagement

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

        // Sync persisted OS-level states on launch (handles reinstall scenarios
        // where UserDefaults may be cleared but the OS still has the record).

        // Launch at login: if SMAppService reports enabled, restore the local flag.
        if SMAppService.mainApp.status == .enabled {
            KeychainStorage.shared.isLaunchAtLoginEnabled = true
        }

        // Reminder sync persistence: if the flag survived reinstall via Keychain,
        // silently re-request OS permission once so sync continues to work.
        if KeychainStorage.shared.isReminderSyncEnabled {
            if !ReminderService.shared.isAuthorized {
                Task {
                    _ = await ReminderService.shared.requestAccess()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        BearBookmarkManager.shared.stopAccessing()
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
