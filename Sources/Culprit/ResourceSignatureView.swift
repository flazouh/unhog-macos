import CulpritCore
import SwiftUI

struct ResourceSignatureView: View {
    let signature: DrainSignature
    var compact = false

    @Environment(\.culpritReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            memoryRow
            cpuRow

            if !compact {
                HStack(spacing: 6) {
                    Text("Energy")
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(CulpritTheme.energy)
                        .frame(width: 5, height: 5)
                    Text(impactLabel)
                        .foregroundStyle(
                            signature.impact == .high
                                ? CulpritTheme.energy
                                : .secondary
                        )
                }
                .font(.system(size: 9, weight: .medium))
            }
        }
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(CulpritTheme.motionEnter) {
                    revealed = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var memoryRow: some View {
        HStack(spacing: compact ? 5 : 8) {
            metricLabel("RAM", symbol: "memorychip")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CulpritTheme.remainder)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CulpritTheme.ram)
                        .frame(
                            width: max(
                                signature.memoryShare > 0 ? 2 : 0,
                                proxy.size.width
                                    * signature.memoryShare
                            )
                        )
                        .scaleEffect(
                            x: revealed ? 1 : 0,
                            y: 1,
                            anchor: .leading
                        )
                }
            }
            .frame(height: compact ? 4 : 8)

            Text(MetricFormatting.memory(signature.memoryBytes))
                .metricValue(compact: compact)
        }
    }

    private var cpuRow: some View {
        HStack(spacing: compact ? 5 : 8) {
            metricLabel("CPU", symbol: "cpu")

            CorePillarsView(
                coreCount: signature.logicalCoreCount,
                usedCores: signature.cpuCores,
                compact: compact,
                revealed: revealed
            )
            .frame(height: compact ? 7 : 16)

            Text(coreValue)
                .metricValue(compact: compact)
        }
    }

    private func metricLabel(
        _ text: String,
        symbol: String
    ) -> some View {
        Group {
            if compact {
                Image(systemName: symbol)
                    .font(.system(size: 7, weight: .medium))
            } else {
                Text(text)
                    .font(.system(size: 9, weight: .medium))
            }
        }
        .foregroundStyle(.secondary)
        .frame(
            width: compact ? 9 : 29,
            alignment: .leading
        )
    }

    private var coreValue: String {
        if signature.cpuCores > 0, signature.cpuCores < 0.1 {
            return "<0.1c"
        }
        return String(format: "%.1fc", signature.cpuCores)
    }

    private var impactLabel: String {
        switch signature.impact {
        case .low: "low"
        case .elevated: "elevated"
        case .high: "high"
        }
    }

    private var accessibilitySummary: String {
        "\(MetricFormatting.memory(signature.memoryBytes)) memory, "
            + "\(String(format: "%.1f", signature.cpuCores)) processor cores, "
            + "\(impactLabel) estimated energy use"
    }
}

private struct CorePillarsView: View {
    let coreCount: Int
    let usedCores: Double
    let compact: Bool
    let revealed: Bool

    var body: some View {
        ZStack {
            pillarCanvas(fillColor: CulpritTheme.remainder) { _ in 1 }

            pillarCanvas(fillColor: CulpritTheme.cpu) { index in
                min(1, max(0, usedCores - Double(index)))
            }
            .scaleEffect(
                x: 1,
                y: revealed ? 1 : 0,
                anchor: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    private func pillarCanvas(
        fillColor: Color,
        fill: @escaping (Int) -> Double
    ) -> some View {
        Canvas { context, size in
            let count = max(1, coreCount)
            let preferredGap: CGFloat = compact ? 1 : 2
            let gap = min(
                preferredGap,
                size.width * 0.25
                    / CGFloat(max(1, count - 1))
            )
            let width = max(
                0.5,
                (
                    size.width
                        - gap * CGFloat(max(0, count - 1))
                ) / CGFloat(count)
            )

            for index in 0 ..< count {
                let height = size.height * fill(index)
                guard height > 0 else { continue }
                let rect = CGRect(
                    x: CGFloat(index) * (width + gap),
                    y: size.height - height,
                    width: width,
                    height: height
                )
                context.fill(
                    Path(
                        roundedRect: rect,
                        cornerRadius: 1
                    ),
                    with: .color(fillColor)
                )
            }
        }
    }
}

private extension View {
    func metricValue(compact: Bool) -> some View {
        font(
            .system(
                size: compact ? 8 : 10,
                weight: .medium,
                design: .rounded
            )
        )
        .monospacedDigit()
        .frame(
            width: compact ? 43 : 58,
            alignment: .trailing
        )
    }
}
