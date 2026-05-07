import SwiftUI

struct ReminderMenuItemView: View {
    let title: String
    let reminderIdentifier: String
    var onToggleComplete: (String, @escaping (Bool) -> Void) -> Void
    var onOpenReminder: () -> Void
    var onRequestRefresh: () -> Void

    @State private var isCompleting = false
    @State private var isCompleted = false
    @State private var showFailed = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                handleCircleTap()
            } label: {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundColor(isCompleting || isCompleted ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(SpringPressButtonStyle())

            Button {
                onOpenReminder()
            } label: {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .opacity(isCompleted ? 0 : 1)
        .frame(height: isCompleted ? 0 : nil)
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleting)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleted)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showFailed)
    }

    private var iconName: String {
        if showFailed { return "circle" }
        if isCompleting || isCompleted { return "circle.fill" }
        return "circle"
    }

    private func handleCircleTap() {
        guard !isCompleting, !isCompleted else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isCompleting = true }
        onToggleComplete(reminderIdentifier) { success in
            if success {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isCompleted = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onRequestRefresh()
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isCompleting = false
                    showFailed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showFailed = false }
                }
            }
        }
    }
}
