import ServiceManagement
import SwiftUI

@main
struct BearTodoMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("Bear Todo", systemImage: "checklist") {
            MenuBarContent(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let accessGranted = BearBookmarkManager.shared.startAccessing()
        if !accessGranted {
            scheduleBookmarkRetry(attempt: 1)
        }

        if SMAppService.mainApp.status == .enabled {
            KeychainStorage.shared.isLaunchAtLoginEnabled = true
        }

        if KeychainStorage.shared.isReminderSyncEnabled {
            let status = ReminderService.shared.authorizationStatus
            if status == .notDetermined {
                Task {
                    _ = await ReminderService.shared.requestAccess()
                }
            } else if ReminderService.shared.isAuthorizedStatus(status) {
                // Already authorized, nothing to do
            } else {
                print("Reminders access denied or restricted (status: \(status.rawValue)), skipping request")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        BearBookmarkManager.shared.stopAccessing()
    }

    @objc func openSettings(_ sender: Any?) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(
            rootView: SettingsView()
                .frame(width: 420)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settings
        window.contentView = hostingView
        window.level = .floating
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(sender)

        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func scheduleBookmarkRetry(attempt: Int) {
        let maxRetries = 3
        guard attempt <= maxRetries else {
            print("Warning: Bear database security-scoped resource access not granted after \(maxRetries) attempts")
            return
        }
        let delays = [2, 5, 10]
        let delay = DispatchTimeInterval.seconds(delays[attempt - 1])
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let granted = BearBookmarkManager.shared.startAccessing()
            if !granted {
                self.scheduleBookmarkRetry(attempt: attempt + 1)
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
