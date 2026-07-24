import SwiftUI

struct LoadingIndicator: View {
    var size: CGFloat = 12

    var body: some View {
        ProgressView()
            .controlSize(size <= 10 ? .mini : .small)
            .accessibilityHidden(true)
    }
}
