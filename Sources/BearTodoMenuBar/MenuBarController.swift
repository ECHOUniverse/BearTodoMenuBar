import Cocoa
import EventKit

private var kNoteIdKey: UInt8 = 0
private var kReminderIdentifierKey: UInt8 = 0

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private static let menuItemMaxWidth: CGFloat = 280
    private static var redDotImage: NSImage = {
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }()
    private var statusItem: NSStatusItem?
    private var noteTodos: [NoteTodos] = []
    private var completedNoteTodos: [NoteTodos] = []
    private var systemReminders: [SystemReminderItem] = []
    private var lastRefreshDate: Date?
    private var isRefreshing = false
    private var isPaused = false
    private let fileWatcher = BearFileWatcher()
    private let remindersDebounce = Debounce(delay: TimeInterval(KeychainStorage.shared.syncInterval))

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
        fileWatcher.updateSyncInterval(TimeInterval(KeychainStorage.shared.syncInterval))
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
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncIntervalDidChange),
            name: .syncIntervalDidChange,
            object: nil
        )
    }

    @objc private func languageDidChange() {
        rebuildMenu()
    }

    @objc private func syncIntervalDidChange() {
        let interval = TimeInterval(KeychainStorage.shared.syncInterval)
        remindersDebounce.delay = interval
        fileWatcher.updateSyncInterval(interval)
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let wasBearFrontmost = bearIsFrontmost
        let wasRemindersFrontmost = remindersIsFrontmost
        bearIsFrontmost = frontmost == "net.shinyfrog.bear"
        remindersIsFrontmost = frontmost == "com.apple.reminders"

        // When leaving Bear, cancel all debounces and refresh immediately
        if wasBearFrontmost && !bearIsFrontmost {
            remindersDebounce.cancel()
            fileWatcher.cancelDebounce()
            refresh()
            return
        }

        // When leaving Reminders, cancel debounce and refresh immediately
        if wasRemindersFrontmost && !remindersIsFrontmost {
            remindersDebounce.cancel()
            refresh()
        }
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
            let refreshingItem = NSMenuItem(title: L10n.refreshing, action: nil, keyEquivalent: "")
            refreshingItem.isEnabled = false
            menu.addItem(refreshingItem)
        } else if let lastRefresh = lastRefreshDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let timeString = formatter.localizedString(for: lastRefresh, relativeTo: Date())
            let refreshItem = NSMenuItem(title: L10n.lastUpdate(timeString), action: #selector(refresh), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)
        } else {
            let refreshItem = NSMenuItem(title: L10n.refreshNow, action: #selector(refresh), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)
        }

        let pauseTitle = isPaused ? L10n.resumeSync : L10n.pauseSync
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        guard KeychainStorage.shared.hasToken else {
            let tokenItem = NSMenuItem(title: L10n.configureTokenFirst, action: #selector(openSettings), keyEquivalent: "")
            tokenItem.target = self
            menu.addItem(tokenItem)
            addFooterItems(to: menu)
            statusItem?.menu = menu
            return
        }

        if KeychainStorage.shared.hasToken && !BearBookmarkManager.shared.hasBookmark {
            let authItem = NSMenuItem(title: L10n.noDatabaseAuth, action: nil, keyEquivalent: "")
            authItem.isEnabled = false
            menu.addItem(authItem)
            menu.addItem(NSMenuItem.separator())
        }

        let allTodos = noteTodos.flatMap { $0.todos }
        let allCompletedTodos = completedNoteTodos.flatMap { $0.todos }

        if allTodos.isEmpty && allCompletedTodos.isEmpty && systemReminders.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.noTodos, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let maxPending = 15
            let maxCompleted = 5
            var pendingDisplayed = 0
            var completedDisplayed = 0

            // 待办区域
            if !allTodos.isEmpty {
                for note in noteTodos {
                    guard pendingDisplayed < maxPending else { break }

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
                        guard pendingDisplayed < maxPending else { break }

                        let todoItem = NSMenuItem()
                        let view = makeWrappingMenuItemView(text: todo.text)
                        bindClickAction(to: view, noteId: todo.noteId)
                        if todo.isReminderCompleted {
                            if let label = view.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
                                label.attributedStringValue = NSAttributedString(
                                    string: todo.text,
                                    attributes: [
                                        .foregroundColor: NSColor.tertiaryLabelColor,
                                        .strikethroughStyle: NSUnderlineStyle.single.rawValue
                                    ]
                                )
                            }
                        }
                        todoItem.view = view
                        menu.addItem(todoItem)
                        pendingDisplayed += 1
                    }
                }
            }

            // 已完成区域
            if KeychainStorage.shared.isReminderSyncEnabled && !allCompletedTodos.isEmpty {
                menu.addItem(NSMenuItem.separator())

                let sectionHeader = NSMenuItem(title: L10n.completedSection, action: nil, keyEquivalent: "")
                sectionHeader.isEnabled = false
                sectionHeader.attributedTitle = NSAttributedString(
                    string: L10n.completedSection,
                    attributes: [
                        .font: NSFont.boldSystemFont(ofSize: 13),
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ]
                )
                menu.addItem(sectionHeader)

                for note in completedNoteTodos {
                    guard completedDisplayed < maxCompleted else { break }

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
                        guard completedDisplayed < maxCompleted else { break }

                        let todoItem = NSMenuItem()
                        let view = makeWrappingMenuItemView(text: todo.text, showRedDot: false)
                        bindClickAction(to: view, noteId: todo.noteId)
                        if let label = view.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
                            label.attributedStringValue = NSAttributedString(
                                string: todo.text,
                                attributes: [
                                    .foregroundColor: NSColor.tertiaryLabelColor,
                                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                                ]
                            )
                        }
                        todoItem.view = view
                        menu.addItem(todoItem)
                        completedDisplayed += 1
                    }
                }
            }

            // 系统提醒事项区域
            let maxReminders = 20
            var remindersDisplayed = 0

            if ReminderService.shared.isAuthorized && !systemReminders.isEmpty {
                menu.addItem(NSMenuItem.separator())

                let sectionHeader = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                sectionHeader.attributedTitle = NSAttributedString(
                    string: L10n.remindersSection,
                    attributes: [
                        .font: NSFont.boldSystemFont(ofSize: 13),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                sectionHeader.isEnabled = false
                menu.addItem(sectionHeader)

                for category in ReminderDueCategory.allCases {
                    let items = systemReminders.filter { $0.dueCategory == category }
                    guard !items.isEmpty else { continue }
                    guard remindersDisplayed < maxReminders else { break }

                    let categoryTitle: String = {
                        switch category {
                        case .today: return L10n.todaySection
                        case .tomorrow: return L10n.tomorrowSection
                        case .scheduled: return L10n.scheduledSection
                        case .unscheduled: return L10n.unscheduledSection
                        }
                    }()
                    let categoryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    categoryItem.attributedTitle = NSAttributedString(
                        string: "> \(categoryTitle)",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11),
                            .foregroundColor: NSColor.tertiaryLabelColor
                        ]
                    )
                    categoryItem.isEnabled = false
                    menu.addItem(categoryItem)

                    for reminder in items {
                        guard remindersDisplayed < maxReminders else { break }
                        let reminderItem = NSMenuItem()
                        reminderItem.view = makeReminderMenuItemView(reminder: reminder)
                        menu.addItem(reminderItem)
                        remindersDisplayed += 1
                    }
                }
            }

            let pendingRemaining = allTodos.count - pendingDisplayed
            let completedRemaining = allCompletedTodos.count - completedDisplayed
            let remindersRemaining = systemReminders.count - remindersDisplayed
            if pendingRemaining > 0 || completedRemaining > 0 || remindersRemaining > 0 {
                let total = pendingRemaining + completedRemaining + remindersRemaining
                let moreItem = NSMenuItem(title: L10n.moreItems(total), action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        }

        addFooterItems(to: menu)
        statusItem?.menu = menu
    }

    private func makeWrappingMenuItemView(text: String, showRedDot: Bool = true) -> NSView {
        let container = NSView(frame: .zero)

        let label = NSTextField(wrappingLabelWithString: text)
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byWordWrapping
        label.font = NSFont.menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)

        if showRedDot {
            let imageView = NSImageView(frame: .zero)
            imageView.image = Self.redDotImage
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)

            label.preferredMaxLayoutWidth = Self.menuItemMaxWidth - 30

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 8),
                imageView.heightAnchor.constraint(equalToConstant: 8),
                label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
            ])
        } else {
            label.preferredMaxLayoutWidth = Self.menuItemMaxWidth - 20

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10)
            ])
        }

        let fitted = label.fittingSize
        container.frame = NSRect(x: 0, y: 0, width: Self.menuItemMaxWidth, height: max(fitted.height + 4, CGFloat(22)))

        return container
    }

    private func bindClickAction(to view: NSView, noteId: String) {
        let click = NSClickGestureRecognizer(target: self, action: #selector(wrappingItemClicked(_:)))
        view.addGestureRecognizer(click)
        objc_setAssociatedObject(view, &kNoteIdKey, noteId, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc private func wrappingItemClicked(_ sender: NSClickGestureRecognizer) {
        guard let view = sender.view,
              let noteId = objc_getAssociatedObject(view, &kNoteIdKey) as? String else { return }
        BearService.shared.openNote(id: noteId)
        view.enclosingMenuItem?.menu?.cancelTracking()
    }

    private func makeReminderMenuItemView(reminder: SystemReminderItem) -> NSView {
        let container = NSView(frame: .zero)

        let imageView = NSImageView(frame: .zero)
        if let image = NSImage(systemSymbolName: "square", accessibilityDescription: nil) {
            imageView.image = image
        }
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(wrappingLabelWithString: reminder.title)
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        label.preferredMaxLayoutWidth = Self.menuItemMaxWidth - 40
        label.font = NSFont.menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 14),
            imageView.heightAnchor.constraint(equalToConstant: 14),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])

        let fitted = label.fittingSize
        let height = max(fitted.height + 4, CGFloat(22))
        container.frame = NSRect(x: 0, y: 0, width: Self.menuItemMaxWidth, height: height)

        objc_setAssociatedObject(container, &kReminderIdentifierKey, reminder.reminderIdentifier, .OBJC_ASSOCIATION_RETAIN)

        let click = NSClickGestureRecognizer(target: self, action: #selector(reminderItemClicked(_:)))
        container.addGestureRecognizer(click)

        return container
    }

    @objc private func reminderItemClicked(_ sender: NSClickGestureRecognizer) {
        guard let view = sender.view,
              let identifier = objc_getAssociatedObject(view, &kReminderIdentifierKey) as? String else {
            return
        }
        ReminderService.shared.toggleReminderCompletion(identifier: identifier) { [weak self] success in
            guard let self = self, success else { return }
            self.refresh()
        }
    }

    private func addFooterItems(to menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L10n.settingsMenu, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func refresh() {
        guard !isPaused else { return }
        guard !isRefreshing else { return }
        guard KeychainStorage.shared.hasToken else {
            rebuildMenu()
            return
        }

        isRefreshing = true
        rebuildMenu()

        BearService.shared.fetchAllUncheckedTodos { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let notes):
                let allTodos = notes.flatMap { $0.todos }
                ReminderService.shared.sync(todos: allTodos) { completedKeys in
                    var pendingNotes: [NoteTodos] = []
                    var completedNotes: [NoteTodos] = []

                    for note in notes {
                        var pendingTodos: [TodoItem] = []
                        var completedTodos: [TodoItem] = []

                        for todo in note.todos {
                            let key = todo.noteId + "|" + String(todo.lineNumber)
                            var updatedTodo = todo
                            updatedTodo.isReminderCompleted = completedKeys.contains(key)
                            if updatedTodo.isReminderCompleted {
                                completedTodos.append(updatedTodo)
                            } else {
                                pendingTodos.append(updatedTodo)
                            }
                        }

                        if !pendingTodos.isEmpty {
                            pendingNotes.append(NoteTodos(id: note.id, title: note.title, todos: pendingTodos))
                        }
                        if !completedTodos.isEmpty {
                            completedNotes.append(NoteTodos(id: note.id, title: note.title, todos: completedTodos))
                        }
                    }

                    self.noteTodos = pendingNotes
                    self.completedNoteTodos = completedNotes

                    // Fetch system reminders after Bear sync
                    ReminderService.shared.fetchUncompletedReminders { items in
                        self.systemReminders = items
                        self.isRefreshing = false
                        self.lastRefreshDate = Date()
                        self.rebuildMenu()
                    }
                }
            case .failure(let error):
                print("Refresh failed: \(error)")
                self.noteTodos = []
                self.completedNoteTodos = []
                self.systemReminders = []
                self.isRefreshing = false
                self.lastRefreshDate = Date()
                self.rebuildMenu()
            }
        }
    }

    @objc private func togglePause() {
        isPaused.toggle()
        if !isPaused {
            refresh()
        } else {
            rebuildMenu()
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
