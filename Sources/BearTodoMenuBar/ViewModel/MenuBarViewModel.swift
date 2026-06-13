import AppKit
import EventKit
import SwiftUI

@Observable @MainActor
final class MenuBarViewModel {
    var noteTodos: [NoteTodos] = []
    var completedNoteTodos: [NoteTodos] = []
    var systemReminders: [SystemReminderItem] = []
    var lastRefreshDate: Date?
    var isRefreshing = false
    var isPaused = false

    private let monitor = MonitorService.shared
    private var bearIsFrontmost = false
    private var remindersIsFrontmost = false
    private var lastRefreshCompletedAt: Date = .distantPast
    private var storage: KeychainStorage { KeychainStorage.shared }

    init() {
        monitor.setOnChange { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.bearIsFrontmost else { return }
                await self.refresh()
            }
        }
        monitor.setDebounceInterval(TimeInterval(storage.syncInterval))
        monitor.start(method: storage.bearMonitorMethod, bookmarkURL: nil)
        setupNotifications()
        Task { await refresh() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func refreshMonitorSettings() {
        monitor.setDebounceInterval(TimeInterval(storage.syncInterval))
        monitor.start(method: storage.bearMonitorMethod, bookmarkURL: nil)
    }

    private func setupNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(activeAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appTerminated), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appHidden), name: NSWorkspace.didHideApplicationNotification, object: nil)
        let dc = NotificationCenter.default
        dc.addObserver(self, selector: #selector(eventStoreChanged), name: .EKEventStoreChanged, object: nil)
        dc.addObserver(self, selector: #selector(menuBecameActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        dc.addObserver(self, selector: #selector(syncIntervalChanged), name: .syncIntervalDidChange, object: nil)
        dc.addObserver(self, selector: #selector(monitorMethodChanged), name: .bearMonitorMethodDidChange, object: nil)
    }

    @objc private func activeAppChanged(_ n: Notification) {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let wasBear = bearIsFrontmost; let wasRem = remindersIsFrontmost
        bearIsFrontmost = front == "net.shinyfrog.bear"; remindersIsFrontmost = front == "com.apple.reminders"
        if (wasBear && !bearIsFrontmost) || (wasRem && !remindersIsFrontmost) {
            monitor.cancelDebounce(); Task { await refresh() }
        }
    }

    @objc private func appTerminated(_ n: Notification) {
        guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "net.shinyfrog.bear" else { return }
        bearIsFrontmost = false; monitor.cancelDebounce(); Task { await refresh() }
    }

    @objc private func appHidden(_ n: Notification) {
        guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "net.shinyfrog.bear" else { return }
        bearIsFrontmost = false; monitor.cancelDebounce(); Task { await refresh() }
    }

    @objc private func eventStoreChanged(_ n: Notification) {
        guard storage.isReminderSyncEnabled, !isRefreshing else { return }
        Task { try? await Task.sleep(for: .seconds(1)); await refresh() }
    }

    @objc private func menuBecameActive() { Task { await refresh() } }

    @objc private func syncIntervalChanged() { monitor.setDebounceInterval(TimeInterval(storage.syncInterval)) }
    @objc private func monitorMethodChanged() { monitor.start(method: storage.bearMonitorMethod, bookmarkURL: nil) }

    func refresh() async {
        guard !isPaused, !isRefreshing else { return }
        guard Date().timeIntervalSince(lastRefreshCompletedAt) >= 2.0 else { return }
        isRefreshing = true
        let cachedCompleted = completedNoteTodos

        do {
            let notes = try await BearService.shared.fetchAllTodos()
            let allTodos = notes.flatMap(\.todos)
            let noteModDates = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0.modified) })
            let syncResult = await ReminderService.shared.sync(todos: allTodos, noteModifiedDates: noteModDates)

            for key in syncResult.completedKeys {
                if let todo = allTodos.first(where: { $0.noteId + "|" + String($0.lineNumber) == key }) {
                    try? await BearService.shared.completeTodo(todo)
                }
            }
            for key in syncResult.uncompletedKeys {
                if let todo = allTodos.first(where: { $0.noteId + "|" + String($0.lineNumber) == key }) {
                    try? await BearService.shared.uncompleteTodo(todo)
                }
            }

            var active: [NoteTodos] = []; var completed: [NoteTodos] = []
            for note in notes {
                let aTodos = note.todos.filter { t in
                    let k = t.noteId + "|" + String(t.lineNumber)
                    if syncResult.completedKeys.contains(k) { return false }
                    if syncResult.uncompletedKeys.contains(k) { return true }
                    return !t.isCompleted
                }
                let cTodos = note.todos.filter { t in
                    let k = t.noteId + "|" + String(t.lineNumber)
                    if syncResult.uncompletedKeys.contains(k) { return false }
                    if syncResult.completedKeys.contains(k) { return true }
                    return t.isCompleted
                }
                if !aTodos.isEmpty { active.append(NoteTodos(id: note.id, title: note.title, todos: aTodos, modified: note.modified)) }
                if !cTodos.isEmpty { completed.append(NoteTodos(id: note.id, title: note.title,
                                                                todos: cTodos.sorted { $0.lineNumber > $1.lineNumber },
                                                                modified: note.modified)) }
            }
            completed.sort { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }

            if notes.isEmpty && !cachedCompleted.isEmpty { noteTodos = []; completedNoteTodos = cachedCompleted }
            else { noteTodos = active; completedNoteTodos = completed }

            systemReminders = await ReminderService.shared.fetchUncompletedReminders()
        } catch {
            print("Refresh failed: \(error)")
            noteTodos = []; completedNoteTodos = []; systemReminders = []
        }
        isRefreshing = false; lastRefreshDate = Date(); lastRefreshCompletedAt = Date()
    }

    func togglePause() { isPaused.toggle(); if !isPaused { Task { await refresh() } } }
    func completeTodo(_ todo: TodoItem) { Task { try? await BearService.shared.completeTodo(todo); await refresh() } }
    func uncompleteTodo(_ todo: TodoItem) { Task { try? await BearService.shared.uncompleteTodo(todo); await refresh() } }
    func openNote(_ todo: TodoItem) { BearService.shared.openNote(id: todo.noteId) }
    func openNoteById(_ noteId: String) { BearService.shared.openNote(id: noteId) }
    func openReminder(_ id: String) { ReminderService.shared.openReminderInApp(identifier: id) }
    func toggleReminderCompletion(_ id: String) { Task { try? await ReminderService.shared.toggleReminderCompletion(identifier: id); await refresh() } }
    func openRemindersApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
