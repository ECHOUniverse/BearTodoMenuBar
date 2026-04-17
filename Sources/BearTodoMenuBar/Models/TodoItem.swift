import Foundation

struct TodoItem: Identifiable {
    let id = UUID()
    let text: String
    let noteId: String
    let noteTitle: String
    let lineNumber: Int
}

struct NoteTodos: Identifiable {
    let id: String
    let title: String
    let todos: [TodoItem]
}
