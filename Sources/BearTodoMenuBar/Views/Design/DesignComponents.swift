import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5)))
    }
}

struct MenuSectionCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5)))
            .padding(.horizontal, 8)
    }
}

struct StatusPill: View {
    let icon: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption).fontWeight(.medium)
        }
        .foregroundColor(color).padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

struct LiquidGlassCircleButton: View {
    let systemImage: String; let accessibilityLabel: LocalizedStringKey; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 13, weight: .medium)).frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .background(Circle().fill(.ultraThinMaterial).shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1))
        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .accessibilityLabel(accessibilityLabel).help(accessibilityLabel)
    }
}

struct SpringPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct StaggeredEntrance: ViewModifier {
    let index: Int; let animate: Bool
    func body(content: Content) -> some View {
        content.opacity(animate ? 1 : 0).offset(y: animate ? 0 : 12)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05), value: animate)
    }
}

extension View {
    func staggeredEntrance(_ index: Int, animate: Bool) -> some View {
        modifier(StaggeredEntrance(index: index, animate: animate))
    }
}

struct GlassEffectTabSwitcher<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let tabs: T.Type
    @Binding var selection: T
    var labelFor: (T) -> Text
    var iconFor: ((T) -> String)?
    var namespace: Namespace.ID
    var onChange: ((T) -> Void)?

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.allCases), id: \.self) { tab in
                    let icon = iconFor?(tab) ?? ""
                    let label = HStack(spacing: 6) {
                        if iconFor != nil { Image(systemName: icon).font(.system(size: 13, weight: .medium)) }
                        labelFor(tab).font(.callout).fontWeight(.medium)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 8)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selection = tab; onChange?(tab)
                        }
                    } label: { label }
                    .buttonStyle(.plain)
                    .if(selection == tab) { $0.glassEffect(.regular.interactive(), in: Capsule()) }
                    .glassEffectID(tab.rawValue, in: namespace)
                }
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(.ultraThinMaterial)
            .overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5)))
        .frame(maxWidth: .infinity)
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
