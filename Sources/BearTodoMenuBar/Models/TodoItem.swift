import Foundation

struct TodoItem: Identifiable {
    let id = UUID()
    let text: String
    let noteId: String
    let noteTitle: String
    let lineNumber: Int
    let isCompleted: Bool
}

struct NoteTodos: Identifiable {
    let id: String
    let title: String
    let todos: [TodoItem]
    let modified: Date?
}

struct SyncResult {
    let completedKeys: Set<String>
    let uncompletedKeys: Set<String>
}

enum ReminderDueCategory: String, CaseIterable {
    case today
    case tomorrow
    case scheduled
    case unscheduled
}

struct SystemReminderItem: Identifiable {
    let id: String
    let title: String
    let dueCategory: ReminderDueCategory
    let reminderIdentifier: String
}
