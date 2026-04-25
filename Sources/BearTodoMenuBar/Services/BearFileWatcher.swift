import Foundation

class BearFileWatcher {
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private let debounce = Debounce(delay: 1.0)
    private let queue = DispatchQueue(label: "com.beartodo.filewatcher")

    var onChange: (() -> Void)?
    var onPermissionDenied: (() -> Void)?

    static func findBearDatabasePath() -> URL? {
        let groupContainersURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: groupContainersURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        for url in contents where url.lastPathComponent.hasSuffix(".net.shinyfrog.bear") {
            let dbURL = url.appendingPathComponent("Application Data/database.sqlite")
            if FileManager.default.fileExists(atPath: dbURL.path) {
                return dbURL
            }
        }
        return nil
    }

    func cancelDebounce() {
        debounce.cancel()
    }

    func startWatching() {
        stopWatching()

        guard let dbURL = BearFileWatcher.findBearDatabasePath() else {
            return
        }

        let path = dbURL.path
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            if errno == EACCES || errno == EPERM {
                DispatchQueue.main.async { [weak self] in
                    self?.onPermissionDenied?()
                }
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.debounce.debounce { [weak self] in
                DispatchQueue.main.async {
                    self?.onChange?()
                }
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        dispatchSource = source
    }

    func stopWatching() {
        if let source = dispatchSource {
            source.setCancelHandler {}
            source.cancel()
            dispatchSource = nil
        }
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    deinit {
        stopWatching()
    }
}
