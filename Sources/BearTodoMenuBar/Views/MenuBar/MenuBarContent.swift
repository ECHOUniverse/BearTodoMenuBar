import SwiftUI

struct MenuBarContent: View {
    @State private var animateContent = false
    let viewModel: MenuBarViewModel
    private var l10n: L10n { L10n.shared }
    private var storage: KeychainStorage { KeychainStorage.shared }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                header.padding(.horizontal, 16).padding(.vertical, 8)
                    .opacity(animateContent ? 1 : 0).animation(.spring(response: 0.4, dampingFraction: 0.8), value: animateContent)

                if storage.bearMonitorMethod == .fileWatcher && !hasBookmark {
                    MenuSectionCard {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow).font(.system(size: 14))
                            Text(l10n.noDatabaseAuth).font(.callout).foregroundColor(.secondary)
                        }.padding(.horizontal, 6)
                    }
                }

                if contentRows.isEmpty {
                    MenuSectionCard { Text(l10n.noTodos).foregroundColor(.secondary).padding(.horizontal, 6) }
                } else {
                    ForEach(Array(contentRows.enumerated()), id: \.offset) { index, row in
                        row.staggeredEntrance(index, animate: animateContent)
                    }
                }

                footer.padding(.horizontal, 16).padding(.vertical, 8)
                    .opacity(animateContent ? 1 : 0).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3), value: animateContent)
            }
            .frame(width: 320)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { DispatchQueue.main.async { animateContent = true } }
    }

    private var hasBookmark: Bool { UserDefaults.standard.data(forKey: "bear_database_bookmark") != nil }

    private var header: some View {
        HStack {
            if viewModel.isRefreshing { Text(l10n.refreshing).font(.callout) }
            else if let last = viewModel.lastRefreshDate {
                Button { Task { await viewModel.refresh() } } label: { Text(l10n.lastUpdate(last.formatted())).font(.callout) }.buttonStyle(.plain)
            } else { Button(l10n.refreshNow) { Task { await viewModel.refresh() } }.buttonStyle(.plain).font(.callout) }
            Spacer()
            Button(viewModel.isPaused ? l10n.resumeSync : l10n.pauseSync) { viewModel.togglePause() }.buttonStyle(.plain).font(.callout)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            LiquidGlassCircleButton(systemImage: "gearshape", accessibilityLabel: LocalizedStringKey(l10n.settingsMenu),
                                     action: { NSApp.sendAction(#selector(AppDelegate.openSettings(_:)), to: NSApp.delegate, from: nil) })
            .keyboardShortcut(",", modifiers: .command)
            Spacer()
            LiquidGlassCircleButton(systemImage: "xmark", accessibilityLabel: LocalizedStringKey(l10n.quit),
                                     action: { NSApp.terminate(nil) }).keyboardShortcut("q", modifiers: .command)
        }
    }

    private var contentRows: [AnyView] {
        var rows: [AnyView] = []
        let bearNotes = viewModel.noteTodos
        let completedNotes = viewModel.completedNoteTodos
        let reminders = viewModel.systemReminders

        guard !bearNotes.flatMap(\.todos).isEmpty || !completedNotes.flatMap(\.todos).isEmpty || !reminders.isEmpty else { return rows }

        var pendingItems: [AnyView] = []; var pendingRemaining = 15
        for note in bearNotes where pendingRemaining > 0 {
            pendingItems.append(AnyView(Button { viewModel.openNoteById(note.id) } label: {
                Text(note.title).font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
            }.buttonStyle(.plain).padding(.horizontal, 6).padding(.top, 2).padding(.bottom, 4)))
            for todo in note.todos.prefix(pendingRemaining) {
                pendingItems.append(AnyView(BearTodoRow(text: todo.text, isCompleted: false,
                    onToggle: { [weak vm = viewModel] in vm?.completeTodo(todo) },
                    onOpenNote: { [weak vm = viewModel] in vm?.openNote(todo) }
                ).id("\(todo.noteId)|\(todo.lineNumber)")))
                pendingRemaining -= 1
            }
        }
        if !pendingItems.isEmpty { rows.append(AnyView(MenuSectionCard { VStack(alignment: .leading, spacing: 0) { ForEach(pendingItems.indices, id: \.self) { pendingItems[$0] } } })) }
        else if !completedNotes.isEmpty { rows.append(AnyView(MenuSectionCard { Text(l10n.allBearTodosCompleted).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.horizontal, 6) })) }

        if !completedNotes.isEmpty && storage.isCompletedSectionVisible {
            var completedItems: [AnyView] = []; var completedRemaining = 5
            completedItems.append(AnyView(Text(l10n.completedSection).font(.system(size: 12, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 6).padding(.top, 2).padding(.bottom, 4)))
            for note in completedNotes where completedRemaining > 0 {
                completedItems.append(AnyView(Button { viewModel.openNoteById(note.id) } label: {
                    Text(note.title).font(.system(size: 11)).foregroundColor(.secondary)
                }.buttonStyle(.plain).padding(.horizontal, 6).padding(.vertical, 2)))
                for todo in note.todos.prefix(completedRemaining) {
                    completedItems.append(AnyView(BearTodoRow(text: todo.text, isCompleted: true,
                        onToggle: { [weak vm = viewModel] in vm?.uncompleteTodo(todo) },
                        onOpenNote: { [weak vm = viewModel] in vm?.openNote(todo) }
                    ).id("\(todo.noteId)|\(todo.lineNumber)")))
                    completedRemaining -= 1
                }
            }
            rows.append(AnyView(MenuSectionCard { VStack(alignment: .leading, spacing: 0) { ForEach(completedItems.indices, id: \.self) { completedItems[$0] } } }))
        }

        if ReminderService.shared.isAuthorized && !reminders.isEmpty {
            var reminderItems: [AnyView] = []; var remRemaining = 20
            reminderItems.append(AnyView(Button { viewModel.openRemindersApp() } label: {
                Text(l10n.remindersSection).font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
            }.buttonStyle(.plain).padding(.horizontal, 6).padding(.top, 2).padding(.bottom, 4)))
            for cat in ReminderDueCategory.allCases where remRemaining > 0 {
                let filtered = reminders.filter { $0.dueCategory == cat }
                guard !filtered.isEmpty else { continue }
                let catTitle = switch cat { case .overdue: l10n.overdueSection; case .today: l10n.todaySection; case .tomorrow: l10n.tomorrowSection; case .scheduled: l10n.scheduledSection; case .unscheduled: l10n.unscheduledSection }
                reminderItems.append(AnyView(Text(catTitle).font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 6).padding(.vertical, 4)))
                for r in filtered.prefix(remRemaining) {
                    reminderItems.append(AnyView(ReminderRow(title: r.title, dueDate: r.dueDate,
                        onToggleComplete: { viewModel.toggleReminderCompletion(r.reminderIdentifier) },
                        onOpenReminder: { viewModel.openReminder(r.reminderIdentifier) }
                    ).id(r.reminderIdentifier)))
                    remRemaining -= 1
                }
            }
            rows.append(AnyView(MenuSectionCard { VStack(alignment: .leading, spacing: 0) { ForEach(reminderItems.indices, id: \.self) { reminderItems[$0] } } }))
        }
        return rows
    }
}
