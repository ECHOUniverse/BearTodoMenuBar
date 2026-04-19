import Cocoa
import EventKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var noteTodos: [NoteTodos] = []
    private var completedNoteTodos: [NoteTodos] = []
    private var lastRefreshDate: Date?
    private var isRefreshing = false
    private let fileWatcher = BearFileWatcher()
    private let remindersDebounce = Debounce(delay: 3.0)

    var onOpenSettings: (() -> Void)?

    override init() {
        super.init()
        setupStatusItem()
        setupFileWatcher()
        setupNotifications()
        refresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private var bearIsFrontmost = false
    private var remindersIsFrontmost = false

    private func setupFileWatcher() {
        fileWatcher.onChange = { [weak self] in
            guard let self = self else { return }
            guard !self.bearIsFrontmost else { return }
            self.refresh()
        }
        fileWatcher.onPermissionDenied = { [weak self] in
            self?.rebuildMenu()
        }
        fileWatcher.startWatching()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .bearAPITokenDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreDidChange),
            name: .EKEventStoreChanged,
            object: ReminderService.shared.eventStore
        )
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        bearIsFrontmost = frontmost == "net.shinyfrog.bear"
        remindersIsFrontmost = frontmost == "com.apple.reminders"
    }

    @objc private func eventStoreDidChange(_ notification: Notification) {
        guard KeychainStorage.shared.isReminderSyncEnabled else { return }
        remindersDebounce.debounce { [weak self] in
            guard let self = self else { return }
            guard !self.remindersIsFrontmost else { return }
            self.refresh()
        }
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
        menu.delegate = self

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

        if KeychainStorage.shared.hasToken && !BearBookmarkManager.shared.hasBookmark {
            let authItem = NSMenuItem(title: "⚠️ 未授权数据库访问，自动刷新不可用", action: nil, keyEquivalent: "")
            authItem.isEnabled = false
            menu.addItem(authItem)
            menu.addItem(NSMenuItem.separator())
        }

        let allTodos = noteTodos.flatMap { $0.todos }
        let allCompletedTodos = completedNoteTodos.flatMap { $0.todos }

        if allTodos.isEmpty && allCompletedTodos.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无待办事项", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            var displayedCount = 0
            let maxTodos = 20

            // 待办区域
            if !allTodos.isEmpty {
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
                        if todo.isReminderCompleted {
                            todoItem.attributedTitle = NSAttributedString(
                                string: "  \(todo.text)",
                                attributes: [.foregroundColor: NSColor.tertiaryLabelColor]
                            )
                        }
                        menu.addItem(todoItem)
                        displayedCount += 1
                    }
                }
            }

            // 已完成区域
            if KeychainStorage.shared.isReminderSyncEnabled && !allCompletedTodos.isEmpty {
                menu.addItem(NSMenuItem.separator())

                let sectionHeader = NSMenuItem(title: "已完成（来自提醒事项）", action: nil, keyEquivalent: "")
                sectionHeader.isEnabled = false
                sectionHeader.attributedTitle = NSAttributedString(
                    string: "已完成（来自提醒事项）",
                    attributes: [
                        .font: NSFont.boldSystemFont(ofSize: 13),
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ]
                )
                menu.addItem(sectionHeader)

                for note in completedNoteTodos {
                    guard displayedCount < maxTodos else { break }

                    let header = NSMenuItem(title: note.title, action: nil, keyEquivalent: "")
                    header.isEnabled = false
                    header.attributedTitle = NSAttributedString(
                        string: note.title,
                        attributes: [
                            .font: NSFont.boldSystemFont(ofSize: 13),
                            .foregroundColor: NSColor.tertiaryLabelColor
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
            }

            let totalCount = allTodos.count + allCompletedTodos.count
            if totalCount > maxTodos {
                let moreItem = NSMenuItem(title: "更多...（共 \(totalCount) 条）", action: nil, keyEquivalent: "")
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

        BearService.shared.fetchAllUncheckedTodos { [weak self] result in
            guard let self = self else { return }
            self.isRefreshing = false
            self.lastRefreshDate = Date()

            switch result {
            case .success(let notes):
                let allTodos = notes.flatMap { $0.todos }
                ReminderService.shared.sync(todos: allTodos) { completedKeys in
                    var pendingNotes: [NoteTodos] = []

                    for note in notes {
                        var displayTodos: [TodoItem] = []

                        for todo in note.todos {
                            let key = todo.noteId + "|" + String(todo.lineNumber)
                            var updatedTodo = todo
                            updatedTodo.isReminderCompleted = completedKeys.contains(key)
                            displayTodos.append(updatedTodo)
                        }

                        if !displayTodos.isEmpty {
                            pendingNotes.append(NoteTodos(id: note.id, title: note.title, todos: displayTodos))
                        }
                    }

                    self.noteTodos = pendingNotes
                    self.completedNoteTodos = []
                    self.rebuildMenu()
                }
            case .failure(let error):
                print("Refresh failed: \(error)")
                self.noteTodos = []
                self.completedNoteTodos = []
                self.rebuildMenu()
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

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
