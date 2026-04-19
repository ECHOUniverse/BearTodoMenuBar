import Foundation
import AppKit

enum BearServiceError: Error {
    case missingToken
    case fetchFailed(String)
    case parseFailed
}

protocol BearServiceProtocol {
    func fetchAllUncheckedTodos(completion: @escaping (Result<[NoteTodos], BearServiceError>) -> Void)
    func openNote(id: String)
}

class BearService: BearServiceProtocol {
    static let shared = BearService()

    func fetchAllUncheckedTodos(completion: @escaping (Result<[NoteTodos], BearServiceError>) -> Void) {
        guard let token = KeychainStorage.shared.token, !token.isEmpty else {
            completion(.failure(.missingToken))
            return
        }

        let url = makeXCallbackURL(
            action: "todo",
            params: [
                "token": token,
                "show_window": "no"
            ]
        )

        XCallbackClient.shared.send(actionURL: url, timeout: 30) { [weak self] result in
            switch result {
            case .success(let params):
                guard let notesJSON = params["notes"],
                      let data = notesJSON.data(using: .utf8),
                      let notes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    completion(.failure(.parseFailed))
                    return
                }

                let noteInfos: [(id: String, title: String)] = notes.compactMap { dict in
                    guard let id = dict["identifier"] as? String,
                          let title = dict["title"] as? String else { return nil }
                    return (id, title)
                }

                self?.fetchNoteContentsSerially(
                    noteInfos: noteInfos,
                    token: token,
                    completion: completion
                )

            case .failure(let error):
                completion(.failure(.fetchFailed(error.localizedDescription)))
            }
        }
    }

    private func fetchNoteContentsSerially(
        noteInfos: [(id: String, title: String)],
        token: String,
        completion: @escaping (Result<[NoteTodos], BearServiceError>) -> Void
    ) {
        guard !noteInfos.isEmpty else {
            completion(.success([]))
            return
        }

        var result: [NoteTodos] = []
        var index = 0

        func fetchNext() {
            guard index < noteInfos.count else {
                completion(.success(result))
                return
            }

            let info = noteInfos[index]
            index += 1

            let url = makeXCallbackURL(
                action: "open-note",
                params: [
                    "id": info.id,
                    "open_note": "no",
                    "show_window": "no",
                    "token": token
                ]
            )

            XCallbackClient.shared.send(actionURL: url, timeout: 30) { response in
                switch response {
                case .success(let params):
                    if let noteText = params["note"] {
                        let unchecked = TodoParser.parseUnchecked(from: noteText)
                        if !unchecked.isEmpty {
                            let todos = unchecked.map { line in
                                TodoItem(text: line.text, noteId: info.id, noteTitle: info.title, lineNumber: line.lineNumber)
                            }
                            result.append(NoteTodos(id: info.id, title: info.title, todos: todos))
                        }
                    }
                case .failure(let error):
                    print("Failed to fetch note \(info.id): \(error)")
                }

                DispatchQueue.main.async {
                    fetchNext()
                }
            }
        }

        fetchNext()
    }

    func openNote(id: String) {
        let url = makeXCallbackURL(action: "open-note", params: ["id": id])
        NSWorkspace.shared.open(url)
    }

    // MARK: - URL Construction

    private func makeXCallbackURL(action: String, params: [String: String]) -> URL {
        var components = URLComponents()
        components.scheme = "bear"
        components.host = "x-callback-url"
        components.path = "/\(action)"

        components.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed))
        }

        // 若解析失败，fallback 到简单字符串拼接（理论上不会失败）
        return components.url ?? URL(string: "bear://x-callback-url/\(action)")!
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&")
        return allowed
    }()
}
