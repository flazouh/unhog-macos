import CulpritCore
import SwiftUI

struct MenuBarSignatureView: View {
    let signature: DrainSignature

    var body: some View {
        VStack(spacing: 3) {
            rail(
                share: signature.memoryShare,
                color: CulpritTheme.ram
            )
            rail(
                share: signature.cpuShare,
                color: CulpritTheme.cpu
            )
        }
        .frame(width: 22)
        .accessibilityHidden(true)
    }

    private func rail(
        share: Double,
        color: Color
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.primary.opacity(0.18))
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(
                        width: max(
                            share > 0 ? 2 : 0,
                            proxy.size.width
                                * min(1, max(0, share))
                        )
                    )
            }
        }
        .frame(height: 3)
    }
}
