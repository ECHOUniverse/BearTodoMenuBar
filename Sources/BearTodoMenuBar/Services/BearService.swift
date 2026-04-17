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

        let url = URL(string: "bear://x-callback-url/todo?token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? token)&show_window=no")!

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

                self?.fetchNoteContentsSequentially(
                    noteInfos: noteInfos,
                    token: token,
                    completion: completion
                )

            case .failure(let error):
                completion(.failure(.fetchFailed(error.localizedDescription)))
            }
        }
    }

    private func fetchNoteContentsSequentially(
        noteInfos: [(id: String, title: String)],
        token: String,
        completion: @escaping (Result<[NoteTodos], BearServiceError>) -> Void
    ) {
        var result: [NoteTodos] = []
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? token

        func processNext(index: Int) {
            guard index < noteInfos.count else {
                completion(.success(result))
                return
            }

            let info = noteInfos[index]
            let url = URL(string: "bear://x-callback-url/open-note?id=\(info.id)&open_note=no&show_window=no&token=\(encodedToken)")!

            XCallbackClient.shared.send(actionURL: url, timeout: 30) { response in
                switch response {
                case .success(let params):
                    guard let noteText = params["note"] else {
                        processNext(index: index + 1)
                        return
                    }

                    let unchecked = TodoParser.parseUnchecked(from: noteText)
                    if !unchecked.isEmpty {
                        let todos = unchecked.map {
                            TodoItem(text: $0, noteId: info.id, noteTitle: info.title)
                        }
                        result.append(NoteTodos(id: info.id, title: info.title, todos: todos))
                    }
                    processNext(index: index + 1)

                case .failure:
                    processNext(index: index + 1)
                }
            }
        }

        processNext(index: 0)
    }

    func openNote(id: String) {
        guard let url = URL(string: "bear://x-callback-url/open-note?id=\(id)") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&")
        return allowed
    }()
}
