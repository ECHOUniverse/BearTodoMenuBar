import SwiftUI
import ServiceManagement

@main
struct BearTodoMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("Bear Todo", systemImage: "checklist") {
            MenuBarContent(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window(L10n.settings, id: "settings") {
            SettingsView()
                .frame(width: 420)
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let accessGranted = BearBookmarkManager.shared.startAccessing()
        if !accessGranted {
            scheduleBookmarkRetry(attempt: 1)
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

    private func scheduleBookmarkRetry(attempt: Int) {
        let maxRetries = 3
        guard attempt <= maxRetries else {
            print("Warning: Bear database security-scoped resource access not granted after \(maxRetries) attempts")
            return
        }
        let delay = DispatchTimeInterval.seconds(attempt)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let granted = BearBookmarkManager.shared.startAccessing()
            if !granted {
                self.scheduleBookmarkRetry(attempt: attempt + 1)
            }
        }
    }
}
