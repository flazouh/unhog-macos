import CulpritCore
import SwiftUI

struct MenuBarSignatureView: View {
    let signature: DrainSignature

    var body: some View {
        VStack(spacing: 3) {
            rail(share: signature.memoryShare)
            rail(share: signature.cpuShare)
        }
        .frame(width: 22)
        .accessibilityHidden(true)
    }

    private func rail(share: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.2))
                Capsule()
                    .fill(.primary)
                    .frame(
                        width: max(
                            share > 0 ? 2 : 0,
                            proxy.size.width * min(1, max(0, share))
                        )
                    )
            }
        }
        .frame(height: 3)
    }
}
