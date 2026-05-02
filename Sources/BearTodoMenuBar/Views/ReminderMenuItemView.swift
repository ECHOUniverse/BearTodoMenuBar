import SwiftUI

struct ReminderMenuItemView: View {
    let title: String
    let reminderIdentifier: String
    let maxWidth: CGFloat
    var onToggleComplete: (String, @escaping (Bool) -> Void) -> Void
    var onRequestRefresh: () -> Void

    @State private var isCompleting = false
    @State private var isCompleted = false
    @State private var showFailed = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundColor(isCompleting || isCompleted ? .accentColor : .secondary)
                .frame(width: 14, height: 14)
                .contentShape(.rect)
                .onTapGesture { handleCircleTap() }

            Text(title)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture { openReminders() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .frame(width: maxWidth, alignment: .leading)
        .opacity(isCompleted ? 0 : 1)
        .animation(.default, value: isCompleting)
        .animation(.default, value: isCompleted)
        .animation(.default, value: showFailed)
    }

    private var iconName: String {
        if showFailed { return "circle" }
        if isCompleting || isCompleted { return "circle.fill" }
        return "circle"
    }

    private func handleCircleTap() {
        guard !isCompleting, !isCompleted else { return }

        withAnimation(.default) { isCompleting = true }

        onToggleComplete(reminderIdentifier) { success in
            if success {
                withAnimation(.default) { isCompleted = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onRequestRefresh()
                }
            } else {
                withAnimation(.default) {
                    isCompleting = false
                    showFailed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.default) { showFailed = false }
                }
            }
        }
    }

    private func openReminders() {
        NSWorkspace.shared.open(URL(string: "x-apple-reminderkit://")!)
    }
}
