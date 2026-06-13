import SwiftUI

struct ReminderRow: View {
    let title: String
    let dueDate: Date?
    let onToggleComplete: () -> Void
    let onOpenReminder: () -> Void

    @State private var isCompleting = false
    @State private var isCompleted = false
    @State private var showFailed = false

    var body: some View {
        HStack(spacing: 8) {
            Button { handleTap() } label: {
                Image(systemName: showFailed ? "circle" : (isCompleting || isCompleted ? "circle.fill" : "circle"))
                    .font(.system(size: 12)).foregroundColor(isCompleting || isCompleted ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(SpringPressButtonStyle())
            Button { onOpenReminder() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).lineLimit(1).truncationMode(.tail)
                    if let dueDate { Text(dueDate, style: .date).font(.system(size: 10)).foregroundColor(.red) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
        .opacity(isCompleted ? 0 : 1).frame(height: isCompleted ? 0 : nil).clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleting)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleted)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showFailed)
    }

    private func handleTap() {
        guard !isCompleting, !isCompleted else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isCompleting = true }
        onToggleComplete()
    }
}
