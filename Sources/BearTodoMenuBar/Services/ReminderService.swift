import AppKit
@preconcurrency import EventKit
import Foundation

final class ReminderService: @unchecked Sendable {
    static let shared = ReminderService()
    private let calendarTitle = "Bear"
    private let notesPrefix = "bear-todo-sync:"
    private var calendarIdentifier: String?

    var authorizationStatus: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .reminder) }
    var isAuthorized: Bool { authorizationStatus == .fullAccess }

    func requestAccess() async -> Bool {
        guard !isAuthorized else { return true }
        do { return try await EKEventStore().requestFullAccessToReminders() }
        catch { print("Reminder access failed: \(error)"); return false }
    }

    func sync(todos: [TodoItem], noteModifiedDates: [String: Date?]) async -> SyncResult {
        guard isAuthorized else { return SyncResult(completedKeys: [], uncompletedKeys: []) }
        let store = EKEventStore()
        guard let calendar = fetchOrCreateCalendar(using: store) else { return SyncResult(completedKeys: [], uncompletedKeys: []) }
        let todoMap = Dictionary(uniqueKeysWithValues: todos.map { (syncKey(for: $0), $0) })
        let prefix = notesPrefix

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: store.predicateForReminders(in: [calendar])) { reminders in
                let existing = reminders ?? []
                var toSave: [EKReminder] = []; var completed = Set<String>(); var uncompleted = Set<String>()

                for r in existing {
                    guard let notes = r.notes, let range = notes.range(of: prefix), range.upperBound < notes.endIndex,
                          let key = Optional.some(String(notes[range.upperBound...])) else { continue }
                    if let todo = todoMap[key] {
                        let bearMod = noteModifiedDates[key.components(separatedBy: "|").first ?? ""] ?? nil
                        if !todo.isCompleted && !r.isCompleted {
                            if r.title != todo.text { r.title = todo.text; toSave.append(r) }
                        } else if !todo.isCompleted && r.isCompleted {
                            if (r.lastModifiedDate ?? .distantPast) > (bearMod ?? .distantPast) { completed.insert(key) }
                            else { r.isCompleted = false; toSave.append(r) }
                        } else if todo.isCompleted && !r.isCompleted {
                            if (r.lastModifiedDate ?? .distantPast) > (bearMod ?? .distantPast) { uncompleted.insert(key) }
                            else { r.isCompleted = true; toSave.append(r) }
                        }
                    } else if !r.isCompleted { r.isCompleted = true; toSave.append(r) }
                }

                let existingKeys = Set(existing.compactMap { r -> String? in
                    guard let notes = r.notes, let range = notes.range(of: prefix), range.upperBound < notes.endIndex
                    else { return nil }
                    return String(notes[range.upperBound...])
                })

                for todo in todos where !todo.isCompleted && !existingKeys.contains("\(todo.noteId)|\(todo.lineNumber)") {
                    let r = EKReminder(eventStore: store); r.title = todo.text
                    r.notes = prefix + "\(todo.noteId)|\(todo.lineNumber)"
                    r.calendar = calendar; r.isCompleted = false
                    let g = Calendar(identifier: .gregorian)
                    if let t = g.date(byAdding: .day, value: 1, to: Date()) {
                        var c = g.dateComponents([.year, .month, .day], from: t); c.calendar = g
                        r.startDateComponents = c; r.dueDateComponents = c
                    }
                    toSave.append(r)
                }

                for r in toSave { do { try store.save(r, commit: r.calendarItemIdentifier.isEmpty) } catch { print("Save: \(error)") } }
                continuation.resume(returning: SyncResult(completedKeys: completed, uncompletedKeys: uncompleted))
            }
        }
    }

    func fetchUncompletedReminders() async -> [SystemReminderItem] {
        guard isAuthorized else { return [] }
        let store = EKEventStore()
        let calendars = store.calendars(for: .reminder).filter { $0.title != calendarTitle }
        guard !calendars.isEmpty else { return [] }
        let prefix = notesPrefix

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: store.predicateForReminders(in: calendars)) { reminders in
                let todayC = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                let tomorrowC = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)

                var overdue: [SystemReminderItem] = [], today: [SystemReminderItem] = []
                var tomorrowItems: [SystemReminderItem] = [], scheduled: [SystemReminderItem] = [], unscheduled: [SystemReminderItem] = []

                for r in (reminders ?? []) {
                    guard !r.isCompleted else { continue }
                    if let notes = r.notes, notes.hasPrefix(prefix) { continue }
                    guard let title = r.title, !title.isEmpty else { continue }

                    let cat: ReminderDueCategory
                    if let comps = r.dueDateComponents, let y = comps.year, let m = comps.month, let d = comps.day {
                        if y == todayC.year, m == todayC.month, d == todayC.day { cat = .today }
                        else if y == tomorrowC.year, m == tomorrowC.month, d == tomorrowC.day { cat = .tomorrow }
                        else {
                            let cal = Calendar.current
                            if let due = cal.date(from: comps), due < cal.startOfDay(for: Date()) { cat = .overdue }
                            else { cat = .scheduled }
                        }
                    } else { cat = .unscheduled }

                    let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                    let item = SystemReminderItem(id: r.calendarItemIdentifier, title: title, dueCategory: cat,
                                                  reminderIdentifier: r.calendarItemIdentifier, dueDate: due)
                    switch cat {
                    case .overdue: overdue.append(item)
                    case .today: today.append(item)
                    case .tomorrow: tomorrowItems.append(item)
                    case .scheduled: scheduled.append(item)
                    case .unscheduled: unscheduled.append(item)
                    }
                }

                func sort(_ items: [SystemReminderItem]) -> [SystemReminderItem] {
                    items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                }
                continuation.resume(returning: sort(overdue) + sort(today) + sort(tomorrowItems) + sort(scheduled) + sort(unscheduled))
            }
        }
    }

    func toggleReminderCompletion(identifier: String) async throws {
        let store = EKEventStore()
        guard let r = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        r.isCompleted = true; try store.save(r, commit: true)
    }

    func openReminderInApp(identifier: String) {
        let store = EKEventStore()
        guard let r = store.calendarItem(withIdentifier: identifier) as? EKReminder, let title = r.title
        else { fallbackOpen(); return }
        let esc = title.replacingOccurrences(of: "\"", with: "\\\"")
        let s = NSAppleScript(source: "tell application \"Reminders\"\nrepeat with lst in lists\nrepeat with rmnd in (reminders of lst whose name is \"\(esc)\")\nreturn id of rmnd\nend repeat\nend repeat\nreturn \"\"\nend tell")
        var err: NSDictionary?
        let rawID = s?.executeAndReturnError(&err).stringValue ?? ""
        guard !rawID.isEmpty, err == nil else { fallbackOpen(); return }
        let link = rawID.replacingOccurrences(of: "x-apple-reminder://", with: "x-apple-reminderkit://REMCDReminder/")
        if let url = URL(string: link) { NSWorkspace.shared.open(url) } else { fallbackOpen() }
    }

    private func fallbackOpen() { if let url = URL(string: "x-apple-reminderkit://") { NSWorkspace.shared.open(url) } }

    private func fetchOrCreateCalendar(using store: EKEventStore) -> EKCalendar? {
        if let id = calendarIdentifier, let cal = store.calendar(withIdentifier: id), cal.allowsContentModifications { return cal }
        if let cal = store.calendars(for: .reminder).first(where: { $0.title == calendarTitle && $0.allowsContentModifications }) {
            calendarIdentifier = cal.calendarIdentifier; return cal
        }
        guard let src = store.defaultCalendarForNewReminders()?.source ?? store.sources.first(where: { $0.sourceType == .local }) else { return nil }
        let cal = EKCalendar(for: .reminder, eventStore: store); cal.title = calendarTitle; cal.source = src
        cal.cgColor = NSColor.systemOrange.cgColor
        do { try store.saveCalendar(cal, commit: true); calendarIdentifier = cal.calendarIdentifier; return cal }
        catch { print("Calendar create: \(error)"); return nil }
    }

    private func syncKey(for todo: TodoItem) -> String { "\(todo.noteId)|\(todo.lineNumber)" }
}
