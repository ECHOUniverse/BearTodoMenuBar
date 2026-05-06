import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            if !BearBookmarkManager.shared.hasBookmark {
                Text(L10n.noDatabaseAuth)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                Divider()
            }
            let rows = buildSectionRows()
            if rows.isEmpty {
                Text(L10n.noTodos)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            } else {
                ForEach(rows.indices, id: \.self) { i in
                    rows[i]
                }
            }
            Divider()
            HStack {
                Button(L10n.settingsMenu) { openWindow(id: "settings") }
                    .buttonStyle(.plain)
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button(L10n.quit) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(width: 280)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack {
            if viewModel.isRefreshing {
                Text(L10n.refreshing)
                    .font(.caption)
            } else if let lastRefresh = viewModel.lastRefreshDate {
                HeaderRefreshButton(lastRefresh: lastRefresh, action: { viewModel.refresh() })
            } else {
                Button(L10n.refreshNow) { viewModel.refresh() }
                    .buttonStyle(.plain)
            }
            Spacer()
            let pauseTitle = viewModel.isPaused ? L10n.resumeSync : L10n.pauseSync
            Button(pauseTitle) { viewModel.togglePause() }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Build rows (non-ViewBuilder, avoids Binding inference)

    private func buildSectionRows() -> [AnyView] {
        var rows: [AnyView] = []
        let bearNotes = viewModel.noteTodos
        let completedNotes = viewModel.completedNoteTodos
        let reminders = viewModel.systemReminders

        if bearNotes.flatMap(\.todos).isEmpty && completedNotes.flatMap(\.todos).isEmpty && reminders.isEmpty {
            return rows
        }

        // Bear todos
        var pendingRemaining = 15
        for note in bearNotes where pendingRemaining > 0 {
            rows.append(AnyView(Text(note.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)))
            for todo in note.todos.prefix(pendingRemaining) {
                rows.append(AnyView(BearTodoMenuItemView(
                    text: todo.text,
                    onComplete: { [weak vm = viewModel] in vm?.completeTodo(todo) },
                    onOpenNote: { [weak vm = viewModel] in vm?.openNote(todo) }
                )))
                pendingRemaining -= 1
            }
        }

        // Completed
        if KeychainStorage.shared.isReminderSyncEnabled {
            let completed = completedNotes
            if !completed.isEmpty {
                var compRemaining = 5
                rows.append(AnyView(Divider()))
                rows.append(AnyView(Text(L10n.completedSection)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)))
                for note in completed where compRemaining > 0 {
                    rows.append(AnyView(Text(note.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 2)
                        .padding(.bottom, 2)))
                    for todo in note.todos.prefix(compRemaining) {
                        rows.append(AnyView(BearTodoMenuItemView(
                            text: todo.text,
                            onComplete: { [weak vm = viewModel] in vm?.completeTodo(todo) },
                            onOpenNote: { [weak vm = viewModel] in vm?.openNote(todo) }
                        )))
                        compRemaining -= 1
                    }
                }
            }
        }

        // Reminders
        if ReminderService.shared.isAuthorized && !reminders.isEmpty {
            var remRemaining = 20
            rows.append(AnyView(Divider()))
            rows.append(AnyView(Text(L10n.remindersSection)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)))
            for category in ReminderDueCategory.allCases where remRemaining > 0 {
                let filtered = reminders.filter { $0.dueCategory == category }
                guard !filtered.isEmpty else { continue }
                let catTitle: String = {
                    switch category {
                    case .today: return L10n.todaySection
                    case .tomorrow: return L10n.tomorrowSection
                    case .scheduled: return L10n.scheduledSection
                    case .unscheduled: return L10n.unscheduledSection
                    }
                }()
                rows.append(AnyView(Text("> \(catTitle)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)))
                for reminder in filtered.prefix(remRemaining) {
                    rows.append(AnyView(ReminderMenuItemView(
                        title: reminder.title,
                        reminderIdentifier: reminder.reminderIdentifier,
                        onToggleComplete: { id, completion in
                            ReminderService.shared.toggleReminderCompletion(identifier: id, completion: completion)
                        },
                        onRequestRefresh: { [weak vm = viewModel] in vm?.refresh() }
                    )))
                    remRemaining -= 1
                }
            }
        }

        // More items
        let pendCnt = bearNotes.flatMap(\.todos).count
        let compCnt = completedNotes.flatMap(\.todos).count
        let pendRem = pendCnt - min(pendCnt, 15)
        let compRem = compCnt - min(compCnt, 5)
        let remdRem = reminders.count - min(reminders.count, 20)
        let total = pendRem + compRem + remdRem
        if total > 0 {
            rows.append(AnyView(Text(L10n.moreItems(total))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)))
        }

        return rows
    }
}

private struct HeaderRefreshButton: View {
    let lastRefresh: Date
    let action: () -> Void

    var body: some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let timeString = formatter.localizedString(for: lastRefresh, relativeTo: Date())
        return Button(L10n.lastUpdate(timeString), action: action)
            .buttonStyle(.plain)
            .font(.caption)
    }
}
