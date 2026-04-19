import EventKit
import Foundation
import AppKit

@MainActor
final class ReminderService {
    static let shared = ReminderService()
    let eventStore = EKEventStore()
    private let calendarTitle = "Bear"
    private let notesPrefix = "bear-todo-sync:"

    private var calendarIdentifier: String?

    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if isAuthorizedStatus(status) {
            return true
        }

        if #available(macOS 14.0, *) {
            do {
                return try await eventStore.requestFullAccessToReminders()
            } catch {
                print("Request full reminder access failed: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        print("Request reminder access failed: \(error)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func sync(todos: [TodoItem], completion: ((Set<String>) -> Void)? = nil) {
        guard KeychainStorage.shared.isReminderSyncEnabled else {
            completion?([])
            return
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard isAuthorizedStatus(status) else {
            print("Reminder access not granted, skipping sync")
            completion?([])
            return
        }

        guard let calendar = fetchOrCreateCalendar() else {
            print("Failed to get or create Bear calendar")
            completion?([])
            return
        }

        calendarIdentifier = calendar.calendarIdentifier

        let bearKeys = Set(todos.map { syncKey(for: $0) })
        let predicate = eventStore.predicateForReminders(in: [calendar])

        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            Task { @MainActor in
                guard let self = self else {
                    completion?([])
                    return
                }

                let existingReminders = reminders ?? []
                var remindersToSave: [EKReminder] = []
                var completedKeys: Set<String> = []

                for reminder in existingReminders {
                    guard let key = self.parseSyncKey(from: reminder.notes) else { continue }

                    if bearKeys.contains(key) {
                        if reminder.isCompleted {
                            completedKeys.insert(key)
                        }
                    } else {
                        if !reminder.isCompleted {
                            reminder.isCompleted = true
                            remindersToSave.append(reminder)
                        }
                    }
                }

                let existingKeys = Set(existingReminders.compactMap { self.parseSyncKey(from: $0.notes) })
                let newTodos = todos.filter { !existingKeys.contains(self.syncKey(for: $0)) }

                for todo in newTodos {
                    let reminder = EKReminder(eventStore: self.eventStore)
                    reminder.title = todo.text
                    reminder.notes = self.notesString(for: todo)
                    reminder.calendar = calendar
                    reminder.isCompleted = false
                    remindersToSave.append(reminder)
                }

                for reminder in remindersToSave {
                    do {
                        try self.eventStore.save(reminder, commit: false)
                    } catch {
                        print("Failed to save reminder: \(error)")
                    }
                }

                if !remindersToSave.isEmpty {
                    do {
                        try self.eventStore.commit()
                    } catch {
                        print("Failed to commit reminders: \(error)")
                    }
                }

                completion?(completedKeys)
            }
        }
    }

    private func isAuthorizedStatus(_ status: EKAuthorizationStatus) -> Bool {
        if status == .authorized { return true }
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return false
    }

    private func fetchOrCreateCalendar() -> EKCalendar? {
        if let identifier = calendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: identifier),
           calendar.allowsContentModifications {
            return calendar
        }

        let existing = eventStore.calendars(for: .reminder).first { $0.title == calendarTitle && $0.allowsContentModifications }
        if let existing = existing {
            calendarIdentifier = existing.calendarIdentifier
            return existing
        }

        guard let source = eventStore.defaultCalendarForNewReminders()?.source else {
            let localSource = eventStore.sources.first { $0.sourceType == .local }
            guard let source = localSource else { return nil }
            return createCalendar(using: source)
        }

        return createCalendar(using: source)
    }

    private func createCalendar(using source: EKSource) -> EKCalendar? {
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.source = source
        calendar.cgColor = NSColor.systemOrange.cgColor

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            calendarIdentifier = calendar.calendarIdentifier
            return calendar
        } catch {
            print("Failed to create Bear calendar: \(error)")
            return nil
        }
    }

    private func syncKey(for todo: TodoItem) -> String {
        return todo.noteId + "|" + String(todo.lineNumber)
    }

    private func notesString(for todo: TodoItem) -> String {
        return notesPrefix + syncKey(for: todo)
    }

    private func parseSyncKey(from notes: String?) -> String? {
        guard let notes = notes else { return nil }
        guard let range = notes.range(of: notesPrefix) else { return nil }
        let startIndex = range.upperBound
        guard startIndex < notes.endIndex else { return nil }
        return String(notes[startIndex...])
    }
}
