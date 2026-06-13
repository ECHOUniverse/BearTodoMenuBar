@preconcurrency import AppKit
import ServiceManagement
import SwiftUI

@main
struct BearTodoMenuBarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("Bear Todo", systemImage: "checklist") {
            MenuBarContent(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var settingsWindow: NSWindow?

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if SMAppService.mainApp.status == .enabled {
            KeychainStorage.shared.isLaunchAtLoginEnabled = true
        }
        if KeychainStorage.shared.isReminderSyncEnabled {
            let status = ReminderService.shared.authorizationStatus
            if status == .notDetermined {
                Task { _ = await ReminderService.shared.requestAccess() }
            }
        }
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {}

    @MainActor @objc func openSettings(_ sender: Any?) {
        if let window = settingsWindow { window.orderOut(nil); settingsWindow = nil }
        let hostingView = AutoSizingHostingView(rootView: SettingsView().frame(minWidth: 420, idealWidth: 460, minHeight: 420))
        let fitSize = hostingView.fittingSize
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: max(460, fitSize.width), height: max(480, fitSize.height)),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L10n.shared.settings
        window.contentView = hostingView; window.level = .floating; window.center()
        window.delegate = self; window.makeKeyAndOrderFront(nil)
        settingsWindow = window; NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: @preconcurrency NSWindowDelegate {
    @MainActor func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
}

private final class AutoSizingHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            let newSize = self.fittingSize
            let delta = newSize.height - window.contentLayoutRect.height
            guard abs(delta) > 4, newSize.height > 0 else { return }
            var frame = window.frame; frame.size.height += delta; frame.origin.y -= delta
            window.setFrame(frame, display: true, animate: true)
        }
    }
}
