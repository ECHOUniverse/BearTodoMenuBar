import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Menu Section Card

struct MenuSectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 8)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

// MARK: - Staggered Entrance

struct StaggeredEntrance: ViewModifier {
    let index: Int
    let animate: Bool

    func body(content: Content) -> some View {
        content
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 12)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05),
                value: animate
            )
    }
}

extension View {
    func staggeredEntrance(_ index: Int, animate: Bool) -> some View {
        modifier(StaggeredEntrance(index: index, animate: animate))
    }
}

// MARK: - Spring Press Button Style

struct SpringPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
