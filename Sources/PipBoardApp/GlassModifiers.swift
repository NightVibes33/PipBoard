import SwiftUI

extension View {
    func pipGlassPanel(cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    func pipGlassControl() -> some View {
        self
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}
