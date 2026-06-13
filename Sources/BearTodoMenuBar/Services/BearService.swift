import Foundation

actor BearService {
    static let shared = BearService()
    private let cliPath = "/Applications/Bear.app/Contents/MacOS/bearcli"

    func fetchAllTodos() async throws -> [NoteTodos] {
        guard FileManager.default.isExecutableFile(atPath: cliPath) else { throw BearServiceError.cliNotFound }
        let json = try await runCLI(["search", "--query", "@todo", "--format", "json", "--fields", "id,title,content,modified"])
        guard !json.isEmpty else { return [] }
        struct CLINote: Decodable { let id: String; let title: String; let content: String; let modified: Date? }
        guard let data = json.data(using: .utf8) else { throw BearServiceError.parseFailed }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CLINote].self, from: data).compactMap { note in
            let todos = TodoParser.parseAllTodos(from: note.content).map {
                TodoItem(text: $0.text, noteId: note.id, noteTitle: note.title, lineNumber: $0.lineNumber, isCompleted: $0.isCompleted)
            }
            return todos.isEmpty ? nil : NoteTodos(id: note.id, title: note.title, todos: todos, modified: note.modified)
        }
    }

    func completeTodo(_ todo: TodoItem) async throws {
        let escaped = todo.text.replacingOccurrences(of: "\\", with: "\\\\")
        _ = try await runCLI(["edit", todo.noteId, "--find", "- [ ] \(escaped)", "--replace", "- [x] \(escaped)", "--all"])
    }

    func uncompleteTodo(_ todo: TodoItem) async throws {
        let escaped = todo.text.replacingOccurrences(of: "\\", with: "\\\\")
        _ = try await runCLI(["edit", todo.noteId, "--find", "- [x] \(escaped)", "--replace", "- [ ] \(escaped)", "--all"])
    }

    nonisolated func openNote(id: String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: cliPath); p.arguments = ["open", id]; try? p.run()
    }

    private func runCLI(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { c in
            let p = Process(); p.executableURL = URL(fileURLWithPath: cliPath); p.arguments = args
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            p.terminationHandler = { proc in
                let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                proc.terminationStatus == 0 ? c.resume(returning: s) : c.resume(throwing: BearServiceError.cliFailed(s))
            }
            do { try p.run() } catch { c.resume(throwing: BearServiceError.cliFailed(error.localizedDescription)) }
        }
    }
}

enum BearServiceError: Error { case cliNotFound, cliFailed(String), parseFailed }
