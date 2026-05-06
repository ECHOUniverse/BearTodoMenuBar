import SwiftUI

struct BearTodoMenuItemView: View {
    let text: String
    var onComplete: () -> Void
    var onOpenNote: () -> Void

    @State private var isCompleting = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isCompleting ? "circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundColor(.red)
                .frame(width: 14, height: 14)
                .contentShape(.rect)
                .onTapGesture { handleCircleTap() }

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
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .opacity(isCompleting ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: isCompleting)
    }

    private func handleCircleTap() {
        guard !isCompleting else { return }
        isCompleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onComplete()
        }
    }
}
