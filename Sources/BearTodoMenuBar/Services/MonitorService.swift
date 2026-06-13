import Foundation

final class MonitorService: @unchecked Sendable {
    static let shared = MonitorService()

    private var dispatchSource: DispatchSourceFileSystemObject? { didSet { oldValue?.cancel() } }
    private var fileDescriptor: CInt = -1
    private var pollingTimer: Timer? { didSet { oldValue?.invalidate() } }
    private var onChangeCallback: (@Sendable () -> Void)?
    private var debounceWorkItem: DispatchWorkItem?
    private var debounceInterval: TimeInterval = 1.0
    private let queue = DispatchQueue(label: "com.beartodo.monitor")

    func setOnChange(_ callback: @Sendable @escaping () -> Void) { onChangeCallback = callback }
    func setDebounceInterval(_ interval: TimeInterval) { debounceInterval = interval }

    func start(method: BearMonitorMethod, bookmarkURL: URL?) {
        stop()
        switch method {
        case .fileWatcher: startFileWatcher(bookmarkURL: bookmarkURL)
        case .polling: startPolling()
        }
    }

    func stop() {
        dispatchSource = nil
        if fileDescriptor >= 0 { close(fileDescriptor); fileDescriptor = -1 }
        pollingTimer = nil; debounceWorkItem?.cancel()
    }

    func cancelDebounce() { debounceWorkItem?.cancel() }

    private func startFileWatcher(bookmarkURL: URL?) {
        guard let dbURL = bookmarkURL ?? Self.findBearDatabasePath() else { return }
        fileDescriptor = open(dbURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.onChangeCallback?() }
            self.debounceWorkItem = item
            self.queue.asyncAfter(deadline: .now() + self.debounceInterval, execute: item)
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor); self.fileDescriptor = -1
        }
        source.resume(); dispatchSource = source
    }

    private func startPolling() {
        let interval = max(debounceInterval > 0 ? debounceInterval : 5.0, 3.0)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onChangeCallback?()
        }
        pollingTimer?.tolerance = interval * 0.2
    }

    static func findBearDatabasePath() -> URL? {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Group Containers")
        guard let c = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return nil }
        for u in c where u.lastPathComponent.hasSuffix(".net.shinyfrog.bear") {
            let db = u.appendingPathComponent("Application Data/database.sqlite")
            if FileManager.default.fileExists(atPath: db.path) { return db }
        }
        return nil
    }
}
