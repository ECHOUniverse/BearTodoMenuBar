import SwiftUI
import AppKit

/// Wraps a SwiftUI view in an NSHostingView with a fixed width.
/// This mirrors the old NSMenu custom view approach where each item's
/// hosting view frame was explicitly set to 280pt.
struct FixedWidthMenuItem: NSViewRepresentable {
    let view: AnyView
    let width: CGFloat

    init<Content: View>(_ view: Content, width: CGFloat) {
        self.view = AnyView(view)
        self.width = width
    }

    func makeNSView(context: Context) -> NSHostingView<AnyView> {
        let hosting = NSHostingView(rootView: view)
        let fitting = hosting.fittingSize
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: max(fitting.height, 22))
        return hosting
    }

    func updateNSView(_ nsView: NSHostingView<AnyView>, context: Context) {
        nsView.rootView = view
        let fitting = nsView.fittingSize
        nsView.frame.size = NSSize(width: width, height: max(fitting.height, 22))
    }
}

/// A text item with fixed width, rendered as a disabled NSMenuItem label
struct FixedWidthMenuText: NSViewRepresentable {
    let text: String
    let width: CGFloat
    let fontWeight: Font.Weight?
    let foregroundColor: Color?
    let fontSize: CGFloat?

    init(
        _ text: String,
        width: CGFloat,
        fontWeight: Font.Weight? = nil,
        foregroundColor: Color? = nil,
        fontSize: CGFloat? = nil
    ) {
        self.text = text
        self.width = width
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.fontSize = fontSize
    }

    func makeNSView(context: Context) -> NSHostingView<AnyView> {
        let hosting = NSHostingView(rootView: AnyView(containedView))
        let fitting = hosting.fittingSize
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: max(fitting.height, 22))
        return hosting
    }

    func updateNSView(_ nsView: NSHostingView<AnyView>, context: Context) {
        nsView.rootView = AnyView(containedView)
        let fitting = nsView.fittingSize
        nsView.frame.size = NSSize(width: width, height: max(fitting.height, 22))
    }

    private var containedView: AnyView {
        if let w = fontWeight, let c = foregroundColor, let s = fontSize {
            return AnyView(Text(text).fontWeight(w).foregroundColor(c).font(.system(size: s)).frame(maxWidth: .infinity, alignment: .leading))
        }
        if let w = fontWeight, let c = foregroundColor {
            return AnyView(Text(text).fontWeight(w).foregroundColor(c).frame(maxWidth: .infinity, alignment: .leading))
        }
        if let w = fontWeight, let s = fontSize {
            return AnyView(Text(text).fontWeight(w).font(.system(size: s)).frame(maxWidth: .infinity, alignment: .leading))
        }
        if let c = foregroundColor, let s = fontSize {
            return AnyView(Text(text).foregroundColor(c).font(.system(size: s)).frame(maxWidth: .infinity, alignment: .leading))
        }
        if let w = fontWeight {
            return AnyView(Text(text).fontWeight(w).frame(maxWidth: .infinity, alignment: .leading))
        }
        if let c = foregroundColor {
            return AnyView(Text(text).foregroundColor(c).frame(maxWidth: .infinity, alignment: .leading))
        }
        if let s = fontSize {
            return AnyView(Text(text).font(.system(size: s)).frame(maxWidth: .infinity, alignment: .leading))
        }
        return AnyView(Text(text).frame(maxWidth: .infinity, alignment: .leading))
    }
}
