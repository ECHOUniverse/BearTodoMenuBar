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

    var isAuthorized: Bool {
        isAuthorizedStatus(EKEventStore.authorizationStatus(for: .reminder))
    }

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

    func sync(todos: [TodoItem], noteModifiedDates: [String: Date?], completion: ((SyncResult) -> Void)? = nil) {
        guard KeychainStorage.shared.isReminderSyncEnabled else {
            completion?(SyncResult(completedKeys: [], uncompletedKeys: []))
            return
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard isAuthorizedStatus(status) else {
            print("Reminder access not granted, skipping sync")
            completion?(SyncResult(completedKeys: [], uncompletedKeys: []))
            return
        }

        guard let calendar = fetchOrCreateCalendar() else {
            print("Failed to get or create Bear calendar")
            completion?(SyncResult(completedKeys: [], uncompletedKeys: []))
            return
        }

        calendarIdentifier = calendar.calendarIdentifier

        let todoMap = Dictionary(uniqueKeysWithValues: todos.map { (syncKey(for: $0), $0) })
        let predicate = eventStore.predicateForReminders(in: [calendar])

        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            Task { @MainActor in
                guard let self = self else {
                    completion?(SyncResult(completedKeys: [], uncompletedKeys: []))
                    return
                }

                let existingReminders = reminders ?? []
                var remindersToSave: [EKReminder] = []
                var completedKeys: Set<String> = []
                var uncompletedKeys: Set<String> = []

                for reminder in existingReminders {
                    guard let key = self.parseSyncKey(from: reminder.notes) else { continue }

                    if let todo = todoMap[key] {
                        // Derive noteId from sync key for timestamp lookup
                        let noteId = key.components(separatedBy: "|").first ?? ""
                        let bearModDate = noteModifiedDates[noteId] ?? nil

                        if !todo.isCompleted && !reminder.isCompleted {
                            // Both unchecked: update title if changed
                            if reminder.title != todo.text {
                                reminder.title = todo.text
                                remindersToSave.append(reminder)
                            }
                        } else if !todo.isCompleted && reminder.isCompleted {
                            // Conflict: Bear unchecked, Reminder completed
                            if self.reminderIsNewer(reminder: reminder, bearModified: bearModDate) {
                                completedKeys.insert(key)
                            } else {
                                reminder.isCompleted = false
                                remindersToSave.append(reminder)
                            }
                        } else if todo.isCompleted && !reminder.isCompleted {
                            // Conflict: Bear checked, Reminder uncompleted
                            if self.reminderIsNewer(reminder: reminder, bearModified: bearModDate) {
                                uncompletedKeys.insert(key)
                            } else {
                                reminder.isCompleted = true
                                remindersToSave.append(reminder)
                            }
                        }
                        // both completed: nothing to do
                    } else {
                        // Todo deleted from Bear
                        if !reminder.isCompleted {
                            reminder.isCompleted = true
                            remindersToSave.append(reminder)
                        }
                    }
                }

                let existingKeys = Set(existingReminders.compactMap { self.parseSyncKey(from: $0.notes) })
                let newTodos = todos.filter { !$0.isCompleted && !existingKeys.contains(self.syncKey(for: $0)) }

                for todo in newTodos {
                    let reminder = EKReminder(eventStore: self.eventStore)
                    reminder.title = todo.text
                    reminder.notes = self.notesString(for: todo)
                    reminder.calendar = calendar
                    reminder.isCompleted = false

                    let gregorian = Calendar(identifier: .gregorian)
                    if let tomorrow = gregorian.date(byAdding: .day, value: 1, to: Date()) {
                        var components = gregorian.dateComponents([.year, .month, .day], from: tomorrow)
                        components.calendar = gregorian
                        reminder.startDateComponents = components
                        reminder.dueDateComponents = components
                    }

                    remindersToSave.append(reminder)
                }

                let newReminders = remindersToSave.filter { $0.calendarItemIdentifier.isEmpty }
                let modifiedReminders = remindersToSave.filter { !$0.calendarItemIdentifier.isEmpty }

                for reminder in newReminders {
                    do {
                        try self.eventStore.save(reminder, commit: true)
                    } catch {
                        print("Failed to save new reminder: \(error)")
                    }
                }

                for reminder in modifiedReminders {
                    do {
                        try self.eventStore.save(reminder, commit: false)
                    } catch {
                        print("Failed to save existing reminder: \(error)")
                    }
                }

                if !modifiedReminders.isEmpty {
                    do {
                        try self.eventStore.commit()
                    } catch {
                        print("Failed to commit reminders: \(error)")
                    }
                }

                completion?(SyncResult(completedKeys: completedKeys, uncompletedKeys: uncompletedKeys))
            }
        }
    }

    private func reminderIsNewer(reminder: EKReminder, bearModified: Date?) -> Bool {
        let reminderDate = reminder.lastModifiedDate ?? Date.distantPast
        let bearDate = bearModified ?? Date.distantPast
        return reminderDate > bearDate
    }

    func fetchUncompletedReminders(completion: @escaping ([SystemReminderItem]) -> Void) {
        let freshStore = EKEventStore()


        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard isAuthorizedStatus(status) else {
            completion([])
            return
        }

        let allCalendars = freshStore.calendars(for: .reminder)
        let filteredCalendars = allCalendars.filter { $0.title != calendarTitle }

        guard !filteredCalendars.isEmpty else {
            completion([])
            return
        }

        let predicate = freshStore.predicateForReminders(in: filteredCalendars)
        freshStore.fetchReminders(matching: predicate) { [weak self] reminders in
            guard let self = self else {
                completion([])
                return
            }


            let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
            let tomorrowComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrowDate)

            var todayItems: [SystemReminderItem] = []
            var tomorrowItems: [SystemReminderItem] = []
            var scheduledItems: [SystemReminderItem] = []
            var unscheduledItems: [SystemReminderItem] = []

            for reminder in (reminders ?? []) {
                guard !reminder.isCompleted else { continue }

                if let notes = reminder.notes, notes.hasPrefix(self.notesPrefix) {
                    continue
                }

                let title = reminder.title ?? ""
                guard !title.isEmpty else { continue }

                let identifier = reminder.calendarItemIdentifier
                let category = self.categorizeDueDate(from: reminder.dueDateComponents, today: todayComponents, tomorrow: tomorrowComponents)
                let item = SystemReminderItem(id: identifier, title: title, dueCategory: category, reminderIdentifier: identifier)

                switch category {
                case .today: todayItems.append(item)
                case .tomorrow: tomorrowItems.append(item)
                case .scheduled: scheduledItems.append(item)
                case .unscheduled: unscheduledItems.append(item)
                }
            }

            let sortBlock: ([SystemReminderItem]) -> [SystemReminderItem] = { items in
                items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            }

            let allItems = sortBlock(todayItems) + sortBlock(tomorrowItems) + sortBlock(scheduledItems) + sortBlock(unscheduledItems)

            Task { @MainActor in
                completion(allItems)
            }
        }
    }

    func toggleReminderCompletion(identifier: String, completion: @escaping (Bool) -> Void) {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            Task { @MainActor in completion(false) }
            return
        }

        reminder.isCompleted = true
        do {
            try eventStore.save(reminder, commit: true)
            Task { @MainActor in completion(true) }
        } catch {
            print("Failed to toggle reminder completion: \(error)")
            Task { @MainActor in completion(false) }
        }
    }

    func openReminderInApp(identifier: String) {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder,
              let title = reminder.title else { return }

        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Reminders"
            repeat with lst in lists
                repeat with rmnd in (reminders of lst whose name is "\(escapedTitle)")
                    return id of rmnd
                end repeat
            end repeat
            return ""
        end tell
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)

        if let err = error {
            print("AppleScript error: \(err)")
            fallbackOpenReminders()
            return
        }

        guard let rawID = result?.stringValue, !rawID.isEmpty else {
            fallbackOpenReminders()
            return
        }

        // x-apple-reminder://UUID → x-apple-reminderkit://REMCDReminder/UUID
        let deepLink = rawID.replacingOccurrences(
            of: "x-apple-reminder://",
            with: "x-apple-reminderkit://REMCDReminder/"
        )

        if let url = URL(string: deepLink) {
            NSWorkspace.shared.open(url)
        } else {
            fallbackOpenReminders()
        }
    }

    private func fallbackOpenReminders() {
        if let url = URL(string: "x-apple-reminderkit://") {
            NSWorkspace.shared.open(url)
        }
    }

    private func categorizeDueDate(from components: DateComponents?, today: DateComponents, tomorrow: DateComponents) -> ReminderDueCategory {
        guard let components = components,
              let year = components.year,
              let month = components.month,
              let day = components.day else {
            return .unscheduled
        }

        if year == today.year && month == today.month && day == today.day {
            return .today
        } else if year == tomorrow.year && month == tomorrow.month && day == tomorrow.day {
            return .tomorrow
        } else {
            return .scheduled
        }
    }

    func isAuthorizedStatus(_ status: EKAuthorizationStatus) -> Bool {
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
