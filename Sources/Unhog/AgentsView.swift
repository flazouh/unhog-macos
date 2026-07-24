import SwiftUI
import UnhogCore

struct AgentsView: View {
    @ObservedObject var store: AgentStore

    @Environment(\.unhogReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if store.isLoading, store.sessions.isEmpty {
                loading
            } else if let errorMessage = store.errorMessage,
                store.sessions.isEmpty
            {
                emptyState(
                    symbol: "exclamationmark.triangle",
                    title: "Agent activity is unavailable",
                    detail: errorMessage
                )
            } else if store.sessions.isEmpty {
                emptyState(
                    symbol: "point.3.connected.trianglepath.dotted",
                    title: "No recent sessions",
                    detail: "Start Codex or Claude to see its work live."
                )
            } else {
                sessionStream
            }
        }
        .onAppear { store.startRefreshing() }
        .onDisappear { store.stopRefreshing() }
        .animation(
            reduceMotion ? nil : UnhogTheme.motionMove,
            value: store.sessions
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent command center")
                    .font(.system(size: 12, weight: .semibold))
                Text(statusLine)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                AgentWorkspaceController.shared.present(
                    store: store,
                    sessionID: store.rootSessions.first?.id
                )
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(InlineActionStyle(compact: true))
            .accessibilityLabel("Open Agent Console")
        }
    }

    private var statusLine: String {
        let active = store.rootSessions.count {
            $0.freshness == .updating
        }
        return "\(active) live · local sessions"
    }

    private var sessionStream: some View {
        VStack(spacing: 8) {
            ForEach(projectGroups) { project in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                        Text(project.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(project.sessions.count)")
                            .monospacedDigit()
                    }
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 9)
                    .frame(height: 20)

                    ForEach(project.sessions) { session in
                        Button {
                            store.select(session.id)
                            AgentWorkspaceController.shared.present(
                                store: store,
                                sessionID: session.id
                            )
                        } label: {
                            CompactAgentRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(4)
        .background(UnhogTheme.surface.opacity(0.72))
        .clipShape(
            RoundedRectangle(
                cornerRadius: UnhogTheme.cornerRadius,
                style: .continuous
            )
        )
    }

    private var projectGroups: [AgentProjectGroup] {
        AgentSessionOrganizer.projects(
            Array(store.rootSessions.prefix(8))
        )
    }

    private var loading: some View {
        HStack(spacing: 9) {
            LoadingIndicator(size: 11)
            Text("Connecting to local sessions…")
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

private struct CompactAgentRow: View {
    let session: AgentSessionSnapshot

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                AgentProviderMark(
                    provider: session.provider,
                    size: 20,
                    isWorking: session.freshness == .updating
                )
                .frame(width: 28, height: 28)
                .background(UnhogTheme.surfaceHover)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                )

                if session.freshness == .updating {
                    Circle()
                        .fill(UnhogTheme.healthy)
                        .frame(width: 6, height: 6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(session.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Image(systemName: activitySymbol)
                        .font(.system(size: 8, weight: .semibold))
                    Text(activityText)
                        .lineLimit(1)
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(relativeUpdate)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(
                        isHovered ? .primary : .tertiary
                    )
            }
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 48)
        .background(
            isHovered
                ? UnhogTheme.surfaceHover
                : Color.clear
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var activityText: String {
        guard let activity = session.latestActivity else {
            return session.model ?? "Waiting"
        }
        if let detail = activity.detail, !detail.isEmpty {
            return "\(activity.title) · \(detail)"
        }
        return activity.title
    }

    private var activitySymbol: String {
        switch session.latestActivity?.kind {
        case .toolCall:
            "hammer"
        case .subagent:
            "point.3.connected.trianglepath.dotted"
        case .assistantMessage:
            "text.bubble"
        default:
            "circle.dotted"
        }
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
}
