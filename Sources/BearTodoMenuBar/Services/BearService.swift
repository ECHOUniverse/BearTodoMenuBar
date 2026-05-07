import Foundation
import AppKit

enum BearServiceError: Error {
    case fetchFailed(String)
    case parseFailed
}

protocol BearServiceProtocol {
    func fetchAllUncheckedTodos(completion: @escaping (Result<[NoteTodos], BearServiceError>) -> Void)
    func openNote(id: String)
}

class BearService: BearServiceProtocol {
    static let shared = BearService()

    private let cliPath = "/Applications/Bear.app/Contents/MacOS/bearcli"

    func fetchAllUncheckedTodos(completion: @escaping (Result<[NoteTodos], BearServiceError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard FileManager.default.isExecutableFile(atPath: cliPath) else {
                DispatchQueue.main.async {
                    completion(.failure(.fetchFailed("Bear CLI not found")))
                }
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["search", "--query", "@todo", "--format", "json", "--fields", "id,title,content,modified"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.fetchFailed(error.localizedDescription)))
                }
                return
            }

            guard process.terminationStatus == 0 else {
                DispatchQueue.main.async {
                    completion(.failure(.fetchFailed("bearcli exited with code \(process.terminationStatus)")))
                }
                return
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

            guard !outputData.isEmpty else {
                DispatchQueue.main.async {
                    completion(.success([]))
                }
                return
            }

            struct CLINote: Decodable {
                let id: String
                let title: String
                let content: String
                let modified: Date?
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let notes = try decoder.decode([CLINote].self, from: outputData)
                let noteTodosList = notes.compactMap { note -> NoteTodos? in
                    let allTodos = TodoParser.parseAllTodos(from: note.content)
                    guard !allTodos.isEmpty else { return nil }
                    let todos = allTodos.map { line in
                        TodoItem(
                            text: line.text,
                            noteId: note.id,
                            noteTitle: note.title,
                            lineNumber: line.lineNumber,
                            isCompleted: line.isCompleted
                        )
                    }
                    return NoteTodos(id: note.id, title: note.title, todos: todos, modified: note.modified)
                }

                DispatchQueue.main.async {
                    completion(.success(noteTodosList))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.parseFailed))
                }
            }
        }
    }

    func completeTodoInBear(todo: TodoItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let escapedText = todo.text.replacingOccurrences(of: "\\", with: "\\\\")
            let oldLine = "- [ ] \(escapedText)"
            let newLine = "- [x] \(escapedText)"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["edit", todo.noteId, "--find", oldLine, "--replace", newLine, "--all"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async { completion(false) }
                return
            }

            DispatchQueue.main.async { completion(process.terminationStatus == 0) }
        }
    }

    func uncompleteTodoInBear(todo: TodoItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let escapedText = todo.text.replacingOccurrences(of: "\\", with: "\\\\")
            let oldLine = "- [x] \(escapedText)"
            let newLine = "- [ ] \(escapedText)"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["edit", todo.noteId, "--find", oldLine, "--replace", newLine, "--all"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async { completion(false) }
                return
            }

            DispatchQueue.main.async { completion(process.terminationStatus == 0) }
        }
    }

    func openNote(id: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["open", id]
        try? process.run()
    }
}
