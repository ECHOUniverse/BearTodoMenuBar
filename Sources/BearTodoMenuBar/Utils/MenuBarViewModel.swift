import Cocoa
import EventKit
import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var noteTodos: [NoteTodos] = []
    @Published var completedNoteTodos: [NoteTodos] = []
    @Published var systemReminders: [SystemReminderItem] = []
    @Published var lastRefreshDate: Date?
    @Published var isRefreshing = false
    @Published var isPaused = false

    private let fileWatcher = BearFileWatcher()
    private let remindersDebounce = Debounce(delay: TimeInterval(KeychainStorage.shared.syncInterval))
    private var bearIsFrontmost = false
    private var remindersIsFrontmost = false

    init() {
        setupFileWatcher()
        setupNotifications()
        refresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Setup

    private func setupFileWatcher() {
        fileWatcher.onChange = { [weak self] in
            guard let self else { return }
            guard !self.bearIsFrontmost else { return }
            self.refresh()
        }
        fileWatcher.onPermissionDenied = {
            // Permission change doesn't need action here — bookmark state is checked in settings
        }
        fileWatcher.startWatching()
        fileWatcher.updateSyncInterval(TimeInterval(KeychainStorage.shared.syncInterval))
    }

    private func setupNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreDidChange),
            name: .EKEventStoreChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncIntervalDidChange),
            name: .syncIntervalDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let wasBearFrontmost = bearIsFrontmost
        let wasRemindersFrontmost = remindersIsFrontmost
        bearIsFrontmost = frontmost == "net.shinyfrog.bear"
        remindersIsFrontmost = frontmost == "com.apple.reminders"

        if wasBearFrontmost && !bearIsFrontmost {
            remindersDebounce.cancel()
            fileWatcher.cancelDebounce()
            refresh()
            return
        }

        if wasRemindersFrontmost && !remindersIsFrontmost {
            remindersDebounce.cancel()
            refresh()
        }
    }

    @objc private func eventStoreDidChange(_ notification: Notification) {
        guard KeychainStorage.shared.isReminderSyncEnabled else { return }
        remindersDebounce.debounce { [weak self] in
            guard let self else { return }
            self.refresh()
        }
    }

    @objc private func menuDidBecomeActive() {
        refresh()
    }

    @objc private func languageDidChange() {
        objectWillChange.send()
    }

    @objc private func syncIntervalDidChange() {
        let interval = TimeInterval(KeychainStorage.shared.syncInterval)
        remindersDebounce.delay = interval
        fileWatcher.updateSyncInterval(interval)
    }

    // MARK: - Refresh

    func refresh() {
        guard !isPaused else { return }
        guard !isRefreshing else { return }

        isRefreshing = true

        let cachedCompleted = self.completedNoteTodos

        BearService.shared.fetchAllUncheckedTodos { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let notes):
                let allTodos = notes.flatMap { $0.todos }
                let noteModDates: [String: Date?] = Dictionary(
                    uniqueKeysWithValues: notes.map { ($0.id, $0.modified) }
                )

                ReminderService.shared.sync(todos: allTodos, noteModifiedDates: noteModDates) { syncResult in
                    if !syncResult.completedKeys.isEmpty {
                        for todo in allTodos {
                            let key = todo.noteId + "|" + String(todo.lineNumber)
                            if syncResult.completedKeys.contains(key) {
                                BearService.shared.completeTodoInBear(todo: todo) { _ in }
                            }
                        }
                    }
                    if !syncResult.uncompletedKeys.isEmpty {
                        for todo in allTodos {
                            let key = todo.noteId + "|" + String(todo.lineNumber)
                            if syncResult.uncompletedKeys.contains(key) {
                                BearService.shared.uncompleteTodoInBear(todo: todo) { _ in }
                            }
                        }
                    }

                    var activeNotes: [NoteTodos] = []
                    var completedNotes: [NoteTodos] = []

                    for note in notes {
                        let active = note.todos.filter { todo in
                            let key = todo.noteId + "|" + String(todo.lineNumber)
                            if syncResult.completedKeys.contains(key) { return false }
                            if syncResult.uncompletedKeys.contains(key) { return true }
                            return !todo.isCompleted
                        }
                        let completed = note.todos.filter { todo in
                            let key = todo.noteId + "|" + String(todo.lineNumber)
                            if syncResult.uncompletedKeys.contains(key) { return false }
                            if syncResult.completedKeys.contains(key) { return true }
                            return todo.isCompleted
                        }
                        if !active.isEmpty {
                            activeNotes.append(NoteTodos(
                                id: note.id, title: note.title,
                                todos: active, modified: note.modified
                            ))
                        }
                        if !completed.isEmpty {
                            completedNotes.append(NoteTodos(
                                id: note.id, title: note.title,
                                todos: completed.sorted { $0.lineNumber > $1.lineNumber },
                                modified: note.modified
                            ))
                        }
                    }

                    completedNotes.sort {
                        ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast)
                    }

                    if notes.isEmpty && !cachedCompleted.isEmpty {
                        self.noteTodos = []
                        self.completedNoteTodos = cachedCompleted
                    } else {
                        self.noteTodos = activeNotes
                        self.completedNoteTodos = completedNotes
                    }

                    ReminderService.shared.fetchUncompletedReminders { items in
                        self.systemReminders = items
                        self.isRefreshing = false
                        self.lastRefreshDate = Date()
                    }
                }
            case .failure(let error):
                print("Refresh failed: \(error)")
                self.noteTodos = []
                self.completedNoteTodos = []
                self.systemReminders = []
                self.isRefreshing = false
                self.lastRefreshDate = Date()
            }
        }
    }

    func togglePause() {
        isPaused.toggle()
        if !isPaused {
            refresh()
        }
    }

    func completeTodo(_ todo: TodoItem) {
        BearService.shared.completeTodoInBear(todo: todo) { [weak self] success in
            guard success else { return }
            self?.refresh()
        }
    }

    func openNote(_ todo: TodoItem) {
        BearService.shared.openNote(id: todo.noteId)
    }

    func uncompleteTodo(_ todo: TodoItem) {
        BearService.shared.uncompleteTodoInBear(todo: todo) { [weak self] success in
            guard success else { return }
            self?.refresh()
        }
    }

    func openReminder(_ identifier: String) {
        ReminderService.shared.openReminderInApp(identifier: identifier)
    }

    func toggleReminder(_ identifier: String) {
        ReminderService.shared.toggleReminderCompletion(identifier: identifier) { [weak self] _ in
            self?.refresh()
        }
    }
}
