import SwiftUI

struct BearTodoMenuItemView: View {
    let text: String
    var onComplete: () -> Void
    var onOpenNote: () -> Void

    @State private var isCompleting = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                handleCircleTap()
            } label: {
                Image(systemName: isCompleting ? "circle.fill" : "circle")
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
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .opacity(isCompleting ? 0 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleting)
    }

    private func handleCircleTap() {
        guard !isCompleting else { return }
        isCompleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onComplete()
        }
    }
}
