import SwiftUI

extension View {
    @ViewBuilder
    func freewriteGlassPanel(cornerRadius: CGFloat = 12, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(
                    interactive ? .regular.interactive() : .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
                )
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                )
        }
    }

    @ViewBuilder
    func freewriteGlassBand(interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(interactive ? .regular.interactive() : .regular, in: .rect)
                .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 0.6))
        } else {
            self
                .background(.ultraThinMaterial)
                .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 0.6))
        }
    }
}

struct FreewriteGlassContainer<Content: View>: View {
    private let spacing: CGFloat?
    private let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
