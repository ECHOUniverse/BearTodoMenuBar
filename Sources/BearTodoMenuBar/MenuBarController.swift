import Cocoa

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var noteTodos: [NoteTodos] = []
    private var lastRefreshDate: Date?
    private var isRefreshing = false

    var onOpenSettings: (() -> Void)?

    override init() {
        super.init()
        setupStatusItem()
        startAutoRefresh()
        setupNotifications()
        refresh()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .bearAPITokenDidChange,
            object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Bear Todo")
            ?? NSImage(systemSymbolName: "note.text", accessibilityDescription: "Bear Todo")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem?.button?.image = image

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if isRefreshing {
            let refreshingItem = NSMenuItem(title: "⏳ 刷新中...", action: nil, keyEquivalent: "")
            refreshingItem.isEnabled = false
            menu.addItem(refreshingItem)
        } else if let lastRefresh = lastRefreshDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let timeString = formatter.localizedString(for: lastRefresh, relativeTo: Date())
            let refreshItem = NSMenuItem(title: "上次更新：\(timeString)", action: #selector(refresh), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)
        } else {
            let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refresh), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)
        }

        menu.addItem(NSMenuItem.separator())

        guard KeychainStorage.shared.hasToken else {
            let tokenItem = NSMenuItem(title: "请先配置 API Token", action: #selector(openSettings), keyEquivalent: "")
            tokenItem.target = self
            menu.addItem(tokenItem)
            addFooterItems(to: menu)
            statusItem?.menu = menu
            return
        }

        let allTodos = noteTodos.flatMap { $0.todos }
        if allTodos.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无待办事项", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            var displayedCount = 0
            let maxTodos = 20

            for note in noteTodos {
                guard displayedCount < maxTodos else { break }

                let header = NSMenuItem(title: note.title, action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.attributedTitle = NSAttributedString(
                    string: note.title,
                    attributes: [
                        .font: NSFont.boldSystemFont(ofSize: 13),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                menu.addItem(header)

                for todo in note.todos {
                    guard displayedCount < maxTodos else { break }

                    let todoItem = NSMenuItem(title: "  \(todo.text)", action: #selector(openNote(_:)), keyEquivalent: "")
                    todoItem.target = self
                    todoItem.representedObject = todo.noteId
                    todoItem.toolTip = "在 Bear 中打开"
                    menu.addItem(todoItem)
                    displayedCount += 1
                }
            }

            if allTodos.count > maxTodos {
                let moreItem = NSMenuItem(title: "更多...（共 \(allTodos.count) 条）", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        }

        addFooterItems(to: menu)
        statusItem?.menu = menu
    }

    private func addFooterItems(to menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func refresh() {
        guard !isRefreshing else { return }
        guard KeychainStorage.shared.hasToken else {
            rebuildMenu()
            return
        }

        isRefreshing = true
        rebuildMenu()

        Task {
            await fetchTodos()
        }
    }

    private func fetchTodos() async {
        await withCheckedContinuation { continuation in
            BearService.shared.fetchAllUncheckedTodos { [weak self] result in
                DispatchQueue.main.async {
                    self?.isRefreshing = false
                    self?.lastRefreshDate = Date()

                    switch result {
                    case .success(let notes):
                        self?.noteTodos = notes
                    case .failure(let error):
                        print("Refresh failed: \(error)")
                    }

                    self?.rebuildMenu()
                    continuation.resume()
                }
            }
        }
    }

    @objc private func openNote(_ sender: NSMenuItem) {
        guard let noteId = sender.representedObject as? String else { return }
        BearService.shared.openNote(id: noteId)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}
