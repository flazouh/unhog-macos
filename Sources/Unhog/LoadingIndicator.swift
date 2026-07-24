import SwiftUI
import UnhogCore

struct LoadingIndicator: View {
    var size: CGFloat = 12

    @Environment(\.unhogReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        Image(systemName: UnhogSymbolName.loading)
            .font(.system(size: size, weight: .semibold))
            .rotationEffect(
                .degrees(
                    reduceMotion ? 0 : isRotating ? 360 : 0
                )
            )
            .animation(
                reduceMotion
                    ? nil
                    : .linear(duration: 1.1)
                        .repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
            .accessibilityHidden(true)
    }
}
