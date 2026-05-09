import SwiftUI

struct BearTodoMenuItemView: View {
    let text: String
    let isCompleted: Bool
    var onToggle: () -> Void
    var onOpenNote: () -> Void

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                handleCircleTap()
            } label: {
                Image(systemName: isAnimating ? iconFilled : iconEmpty)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(SpringPressButtonStyle())

            Button {
                onOpenNote()
            } label: {
                Text(text)
                    .font(.body)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .opacity(isAnimating && !isCompleted ? 0 : 1)
        .frame(height: isAnimating && !isCompleted ? 0 : nil)
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isAnimating)
    }

    private var iconEmpty: String {
        isCompleted ? "checkmark.circle.fill" : "circle"
    }

    private var iconFilled: String {
        isCompleted ? "circle" : "checkmark.circle.fill"
    }

    private func handleCircleTap() {
        guard !isAnimating else { return }
        isAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onToggle()
        }
    }
}
