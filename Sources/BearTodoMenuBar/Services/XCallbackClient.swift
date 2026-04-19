import Foundation
import AppKit

enum XCallbackError: Error {
    case callbackFailed(String)
    case timeout
    case invalidCallback
}

final class XCallbackClient {
    static let shared = XCallbackClient()
    private init() {}

    private var pending: [String: (Result<[String: String], XCallbackError>) -> Void] = [:]
    private let queue = DispatchQueue(label: "com.beartodo.xcallback")
    private var timeoutTimers: [String: Timer] = [:]

    func send(
        actionURL: URL,
        timeout: TimeInterval = 30,
        completion: @escaping (Result<[String: String], XCallbackError>) -> Void
    ) {
        let requestId = UUID().uuidString

        queue.sync {
            pending[requestId] = completion
        }

        guard var components = URLComponents(url: actionURL, resolvingAgainstBaseURL: true) else {
            complete(requestId: requestId, result: .failure(.invalidCallback))
            return
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "x-success", value: "beartodo://callback/success?id=\(requestId)"))
        queryItems.append(URLQueryItem(name: "x-error", value: "beartodo://callback/error?id=\(requestId)"))
        components.queryItems = queryItems

        guard let url = components.url else {
            complete(requestId: requestId, result: .failure(.invalidCallback))
            return
        }

        DispatchQueue.main.async { [weak self] in
            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                self?.complete(requestId: requestId, result: .failure(.timeout))
            }

            self?.queue.sync {
                self?.timeoutTimers[requestId] = timer
            }

            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.open(url, configuration: config, completionHandler: nil)
        }
    }

    func receive(urls: [URL]) {
        for url in urls {
            receive(url: url)
        }
    }

    func receive(url: URL) {
        guard url.scheme == "beartodo",
              url.host == "callback" else {
            return
        }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let params = components?.queryItems?.reduce(into: [String: String]()) { dict, item in
            dict[item.name] = item.value
        } ?? [:]

        guard let requestId = params["id"] else { return }

        if path == "success" {
            complete(requestId: requestId, result: .success(params))
        } else if path == "error" {
            let message = params["errorMessage"] ?? "Unknown error"
            complete(requestId: requestId, result: .failure(.callbackFailed(message)))
        }
    }

    private func complete(requestId: String, result: Result<[String: String], XCallbackError>) {
        queue.sync {
            timeoutTimers[requestId]?.invalidate()
            timeoutTimers.removeValue(forKey: requestId)

            guard let completion = pending.removeValue(forKey: requestId) else { return }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
