import CulpritCore
import SwiftUI

struct ResourceSignatureView: View {
    let signature: DrainSignature
    let color: Color
    var compact = false

    @Environment(\.culpritReduceMotion) private var reduceMotion
    @State private var revealProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            if signature.primarySignal == .cpu {
                cpuRow
                memoryRow
            } else {
                memoryRow
                cpuRow
            }

            if !compact {
                impactRow
            }
        }
        .opacity(revealProgress)
        .onAppear {
            guard revealProgress == 0 else { return }
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) {
                    revealProgress = 1
                }
            } else {
                withAnimation(
                    .timingCurve(
                        0.23,
                        1,
                        0.32,
                        1,
                        duration: 0.2
                    )
                ) {
                    revealProgress = 1
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var memoryRow: some View {
        metricFrame(
            symbol: "memorychip",
            label: "RAM",
            value: MetricFormatting.memory(signature.memoryBytes)
        ) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CulpritTheme.remainder)
                    Capsule()
                        .fill(color)
                        .frame(
                            width: max(
                                signature.memoryShare > 0 ? 3 : 0,
                                proxy.size.width * signature.memoryShare
                            )
                        )
                        .scaleEffect(
                            x: revealProgress,
                            y: 1,
                            anchor: .leading
                        )
                }
            }
            .frame(height: compact ? 5 : 7)
        }
    }

    @ViewBuilder
    private var cpuRow: some View {
        if compact {
            metricFrame(
                symbol: "cpu",
                label: "CPU",
                value: coreValue
            ) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(CulpritTheme.remainder)
                        Capsule()
                            .fill(color)
                            .frame(
                                width: max(
                                    signature.cpuShare > 0 ? 3 : 0,
                                    proxy.size.width * signature.cpuShare
                                )
                            )
                            .scaleEffect(
                                x: revealProgress,
                                y: 1,
                                anchor: .leading
                            )
                    }
                }
                .frame(height: 5)
            }
        } else {
            metricFrame(
                symbol: "cpu",
                label: "CPU",
                value:
                    "\(coreValue) / \(signature.logicalCoreCount)"
            ) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(
                        0 ..< signature.logicalCoreCount,
                        id: \.self
                    ) { index in
                        cpuPillar(index: index)
                    }
                }
                .frame(height: 16)
            }
        }
    }

    private func cpuPillar(index: Int) -> some View {
        GeometryReader { proxy in
            let fill = min(
                1,
                max(0, signature.cpuCores - Double(index))
            )
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(CulpritTheme.remainder)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(height: proxy.size.height * fill)
                    .scaleEffect(
                        x: 1,
                        y: revealProgress,
                        anchor: .bottom
                    )
            }
        }
    }

    private var impactRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "battery.75percent")
                .frame(width: 13)
            Text("Impact")
                .frame(width: 38, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(
                            index < impactLevel
                                ? color
                                : CulpritTheme.remainder
                        )
                        .frame(width: 6, height: 6)
                        .scaleEffect(revealProgress)
                }
            }
            Spacer()
            Text(impactLabel)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 9, weight: .medium))
    }

    private func metricFrame<Content: View>(
        symbol: String,
        label: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 7) {
            if compact {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
            } else {
                Image(systemName: symbol)
                    .frame(width: 13)
                Text(label)
                    .frame(width: 38, alignment: .leading)
            }

            content()

            Text(value)
                .font(
                    .system(
                        size: compact ? 9 : 10,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .monospacedDigit()
                .foregroundStyle(compact ? .secondary : .primary)
                .frame(
                    width: compact ? 52 : 72,
                    alignment: .trailing
                )
        }
    }

    private var coreValue: String {
        let cores = signature.cpuCores
        if cores > 0, cores < 0.1 {
            return "<0.1c"
        }
        return String(format: "%.1fc", cores)
    }

    private var impactLevel: Int {
        switch signature.impact {
        case .low: 1
        case .elevated: 2
        case .high: 3
        }
    }

    private var impactLabel: String {
        switch signature.impact {
        case .low: "looks low"
        case .elevated: "may be elevated"
        case .high: "likely high"
        }
    }

    private var accessibilitySummary: String {
        "\(MetricFormatting.memory(signature.memoryBytes)) memory, "
            + "\(String(format: "%.1f", signature.cpuCores)) processor cores "
            + "out of \(signature.logicalCoreCount), "
            + "\(impactLabel) estimated impact"
    }
}
