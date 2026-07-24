import SwiftUI
import UnhogCore

struct AgentsView: View {
    @ObservedObject var store: AgentStore

    @Environment(\.unhogReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summary

            if store.isLoading, store.sessions.isEmpty {
                loading
            } else if let errorMessage = store.errorMessage,
                      store.sessions.isEmpty {
                emptyState(
                    symbol: "exclamationmark.triangle",
                    title: "Agent activity is unavailable",
                    detail: errorMessage
                )
            } else if store.sessions.isEmpty {
                emptyState(
                    symbol: "sparkles",
                    title: "No recent agents",
                    detail: "Codex and Claude sessions will appear here."
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(store.sessions) { session in
                        AgentSessionRow(session: session)
                    }
                }
            }
        }
        .onAppear {
            store.startRefreshing()
        }
        .onDisappear {
            store.stopRefreshing()
        }
        .animation(
            reduceMotion ? nil : UnhogTheme.motionMove,
            value: store.sessions
        )
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent windows")
                    .font(.system(size: 12, weight: .semibold))
                Text("Local sessions · nothing leaves this Mac")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !store.sessions.isEmpty {
                Text(
                    "\(updatingCount) updating"
                )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    updatingCount > 0
                        ? UnhogTheme.healthyForeground
                        : .secondary
                )
                .monospacedDigit()
            }
        }
    }

    private var updatingCount: Int {
        store.sessions.count { $0.freshness == .updating }
    }

    private var loading: some View {
        HStack(spacing: 9) {
            LoadingIndicator(size: 11)
            Text("Finding local agent sessions…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
    }

    private func emptyState(
        symbol: String,
        title: String,
        detail: String
    ) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(UnhogTheme.subtleText)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 108)
        .padding(.horizontal, 24)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
    }
}

private struct AgentSessionRow: View {
    let session: AgentSessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                providerMark

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(session.name)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        if session.freshness == .updating {
                            Circle()
                                .fill(UnhogTheme.healthy)
                                .frame(width: 5, height: 5)
                                .accessibilityLabel("Updating")
                        }
                    }

                    Text(sessionSubtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(relativeUpdate)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(
                            cornerRadius: 3,
                            style: .continuous
                        )
                        .fill(UnhogTheme.remainder)

                        RoundedRectangle(
                            cornerRadius: 3,
                            style: .continuous
                        )
                        .fill(providerColor)
                        .frame(
                            width: proxy.size.width
                                * session.contextShare
                        )
                    }
                }
                .frame(height: 7)

                HStack {
                    Text("Context")
                    Spacer()
                    Text(contextLabel)
                        .monospacedDigit()
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(11)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }

    private var providerMark: some View {
        Image(
            systemName: session.provider == .codex
                ? "terminal"
                : "sparkles"
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(providerColor)
        .frame(width: 27, height: 27)
        .background(UnhogTheme.surfaceHover)
        .clipShape(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
    }

    private var providerColor: Color {
        session.provider == .codex
            ? UnhogTheme.cpu
            : UnhogTheme.selection
    }

    private var sessionSubtitle: String {
        [
            session.provider == .codex ? "Codex" : "Claude",
            session.projectName,
            session.model
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var contextLabel: String {
        let prefix = session.contextWindowConfidence == .estimated
            ? "~"
            : ""
        return "\(prefix)\(percent(session.contextShare)) · "
            + "\(tokens(session.contextTokens)) / "
            + tokens(session.contextWindowTokens)
    }

    private var relativeUpdate: String {
        let seconds = max(
            0,
            Int(Date().timeIntervalSince(session.updatedAt))
        )
        if seconds < 60 { return "now" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        return "\(seconds / 3_600)h"
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func tokens(_ value: UInt64) -> String {
        if value >= 1_000_000 {
            return String(
                format: "%.1fM",
                Double(value) / 1_000_000
            )
        }
        if value >= 1_000 {
            return "\(Int((Double(value) / 1_000).rounded()))K"
        }
        return "\(value)"
    }
}
