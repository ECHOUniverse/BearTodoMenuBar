import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var animateContent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animateContent)

            if !BearBookmarkManager.shared.hasBookmark {
                MenuSectionCard {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                        Text(L10n.noDatabaseAuth)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                }
            }

            let rows = buildSectionRows()
            if rows.isEmpty {
                MenuSectionCard {
                    Text(L10n.noTodos)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                }
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    row
                        .staggeredEntrance(index, animate: animateContent)
                }
            }

            HStack {
                Button(L10n.settingsMenu) { openWindow(id: "settings") }
                    .buttonStyle(.plain)
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button(L10n.quit) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .opacity(animateContent ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3), value: animateContent)
        }
        .frame(width: 320)
        .onAppear {
            DispatchQueue.main.async {
                animateContent = true
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack {
            if viewModel.isRefreshing {
                Text(L10n.refreshing)
                    .font(.callout)
            } else if let lastRefresh = viewModel.lastRefreshDate {
                HeaderRefreshButton(lastRefresh: lastRefresh, action: { viewModel.refresh() })
            } else {
                Button(L10n.refreshNow) { viewModel.refresh() }
                    .buttonStyle(.plain)
                    .font(.callout)
            }
            Spacer()
            let pauseTitle = viewModel.isPaused ? L10n.resumeSync : L10n.pauseSync
            Button(pauseTitle) { viewModel.togglePause() }
                .buttonStyle(.plain)
                .font(.callout)
        }
    }

    // MARK: - Build section card rows

    private func buildSectionRows() -> [AnyView] {
        var rows: [AnyView] = []
        let bearNotes = viewModel.noteTodos
        let reminders = viewModel.systemReminders

        if bearNotes.flatMap(\.todos).isEmpty && reminders.isEmpty {
            return rows
        }

        // Bear pending todos card
        var pendingRemaining = 15
        var pendingItems: [AnyView] = []
        for note in bearNotes where pendingRemaining > 0 {
            pendingItems.append(AnyView(
                Text(note.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
            ))
            for todo in note.todos.prefix(pendingRemaining) {
                pendingItems.append(AnyView(BearTodoMenuItemView(
                    text: todo.text,
                    onComplete: { [weak vm = viewModel] in vm?.completeTodo(todo) },
                    onOpenNote: { [weak vm = viewModel] in vm?.openNote(todo) }
                )))
                pendingRemaining -= 1
            }
        }
        if !pendingItems.isEmpty {
            rows.append(AnyView(
                MenuSectionCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(pendingItems.indices, id: \.self) { pendingItems[$0] }
                    }
                }
            ))
        }

        // Reminders card
        if ReminderService.shared.isAuthorized && !reminders.isEmpty {
            var remRemaining = 20
            var reminderItems: [AnyView] = []
            reminderItems.append(AnyView(
                Text(L10n.remindersSection)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
            ))
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
                reminderItems.append(AnyView(
                    Text(catTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                ))
                for reminder in filtered.prefix(remRemaining) {
                    reminderItems.append(AnyView(ReminderMenuItemView(
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
            rows.append(AnyView(
                MenuSectionCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(reminderItems.indices, id: \.self) { reminderItems[$0] }
                    }
                }
            ))
        }

        // More items indicator
        let pendCnt = bearNotes.flatMap(\.todos).count
        let pendRem = pendCnt - min(pendCnt, 15)
        let remdRem = reminders.count - min(reminders.count, 20)
        let total = pendRem + remdRem
        if total > 0 {
            rows.append(AnyView(
                MenuSectionCard {
                    Text(L10n.moreItems(total))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                }
            ))
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
            .font(.callout)
    }
}
