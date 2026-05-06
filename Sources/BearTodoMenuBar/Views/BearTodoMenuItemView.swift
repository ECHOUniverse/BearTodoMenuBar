import AppKit
import SwiftUI

struct BearTodoMenuItemView: View {
    let text: String
    let maxWidth: CGFloat
    var onComplete: () -> Void
    var onOpenNote: () -> Void

    @State private var isCompleting = false

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: isCompleting ? Self.checkedCircleImage : Self.uncheckedCircleImage)
                .frame(width: 14, height: 14)
                .contentShape(.rect)
                .onTapGesture { handleCircleTap() }

            Text(text)
                .font(.body)
                .lineLimit(nil)
                .onTapGesture { onOpenNote() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .frame(width: maxWidth, alignment: .leading)
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

    private static var uncheckedCircleImage: NSImage = {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setStroke()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 10, height: 10)).stroke()
        image.unlockFocus()
        return image
    }()

    private static var checkedCircleImage: NSImage = {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setStroke()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 10, height: 10)).stroke()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: 3.5, y: 3.5, width: 5, height: 5)).fill()
        image.unlockFocus()
        return image
    }()
}
