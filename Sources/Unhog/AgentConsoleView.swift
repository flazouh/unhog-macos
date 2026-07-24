import AppKit
import SwiftUI
import UnhogCore

@MainActor
final class AgentWorkspaceController: NSObject, NSWindowDelegate {
    static let shared = AgentWorkspaceController()

    private var window: NSWindow?

    func present(store: AgentStore, sessionID: String?) {
        if let sessionID {
            store.select(sessionID)
        }

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = AgentConsoleView(store: store)
            .environment(
                \.unhogReduceMotion,
                NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
        let controller = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: controller)
        window.title = "Unhog Agents"
        window.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 720, height: 520)
        window.setContentSize(NSSize(width: 900, height: 640))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

struct AgentConsoleView: View {
    @ObservedObject var store: AgentStore

    @State private var searchText = ""
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            appHeader
            Divider().opacity(0.34)

            HSplitView {
                sidebar
                    .frame(minWidth: 180, idealWidth: 204, maxWidth: 236)

                conversation
                    .frame(minWidth: 500, maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { store.startRefreshing() }
        .onDisappear { store.stopRefreshing() }
        .onChange(of: store.selectedSessionID) {
            draft = ""
        }
    }

    private var appHeader: some View {
        HStack(spacing: 9) {
            UnhogMenuBarMark()
            Text("Agents")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            Circle()
                .fill(
                    activeCount > 0
                        ? UnhogTheme.healthy
                        : Color.secondary
                )
                .frame(width: 5, height: 5)
            Text("\(activeCount) live")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "lock")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .help("All session data stays on this Mac")
        }
        .padding(.horizontal, 14)
        .padding(.top, 27)
        .padding(.bottom, 9)
    }

    private var activeCount: Int {
        store.rootSessions.count { $0.freshness == .updating }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Threads")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("\(filteredSessions.count)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 5)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(UnhogTheme.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(projectGroups) { project in
                        VStack(alignment: .leading, spacing: 2) {
                            ProjectHeader(project: project)

                            ForEach(project.sessions) { session in
                                ThreadRow(
                                    session: session,
                                    isSelected:
                                        store.selectedSession?.id
                                        == session.id
                                ) {
                                    store.select(session.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(9)
        .background(UnhogTheme.surface.opacity(0.22))
    }

    private var filteredSessions: [AgentSessionSnapshot] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return store.rootSessions }
        return store.rootSessions.filter {
            [
                $0.name,
                $0.projectName,
                $0.model,
            ]
            .compactMap { $0 }
            .contains {
                $0.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private var projectGroups: [AgentProjectGroup] {
        AgentSessionOrganizer.projects(filteredSessions)
    }

    @ViewBuilder
    private var conversation: some View {
        if let session = store.selectedSession {
            VStack(spacing: 0) {
                conversationHeader(session)
                Divider().opacity(0.3)
                timeline(session)
                composer(session)
            }
        } else {
            VStack(spacing: 7) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
                Text("Choose a thread")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func conversationHeader(
        _ session: AgentSessionSnapshot
    ) -> some View {
        HStack(spacing: 8) {
            AgentProviderMark(
                provider: session.provider,
                size: 24,
                isWorking: session.freshness == .updating
            )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(session.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    if session.freshness == .updating {
                        Circle()
                            .fill(UnhogTheme.healthy)
                            .frame(width: 5, height: 5)
                    }
                }
                Text(session.projectName ?? session.provider.rawValue)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(contextPercent(session)) ctx")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if session.workingDirectory != nil {
                Button {
                    openWorkingDirectory(session)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(InlineActionStyle(compact: true))
                .accessibilityLabel("Open project")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
    }

    private func timeline(
        _ session: AgentSessionSnapshot
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.timeline.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: "circle.dotted")
                                .font(.system(size: 15))
                                .foregroundStyle(.tertiary)
                            Text("Waiting for activity")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(session.timeline) { entry in
                            TimelineEntryView(
                                entry: entry,
                                nestedSession: store.nestedSession(
                                    for: entry
                                )
                            )
                            .id(entry.id)
                        }

                        ForEach(
                            store.backgroundSessions(for: session)
                        ) { backgroundSession in
                            BackgroundAgentEntryView(
                                session: backgroundSession
                            )
                            .id(backgroundSession.id)
                        }
                    }
                }
                .frame(maxWidth: 700)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: session.timeline.last?.id) {
                guard let id = session.timeline.last?.id else {
                    return
                }
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private func composer(
        _ session: AgentSessionSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "Message \(session.name)…",
                text: $draft,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .lineLimit(1...6)
            .padding(.horizontal, 11)
            .padding(.top, 10)
            .padding(.bottom, 7)

            HStack(spacing: 8) {
                ModelControl(store: store, session: session)

                Text("\(contextPercent(session)) context")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                Spacer()

                statusMark(session)

                Button {
                    let message = draft
                    draft = ""
                    store.send(message, to: session)
                } label: {
                    Group {
                        if store.status(for: session.id) == .sending {
                            LoadingIndicator(size: 10)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .frame(width: 27, height: 27)
                }
                .buttonStyle(
                    InlineActionStyle(
                        tone: draftIsEmpty
                            ? .secondary
                            : UnhogTheme.cpu,
                        compact: true
                    )
                )
                .disabled(
                    draftIsEmpty
                        || store.status(for: session.id) == .sending
                )
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Send message")
            }
            .padding(.leading, 9)
            .padding(.trailing, 6)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: 700)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statusMark(
        _ session: AgentSessionSnapshot
    ) -> some View {
        switch store.status(for: session.id) {
        case .idle:
            EmptyView()
        case .sending:
            Text("working")
                .foregroundStyle(UnhogTheme.cpu)
        case .sent:
            Image(systemName: "checkmark")
                .foregroundStyle(UnhogTheme.healthyForeground)
        case .failed:
            Image(systemName: "exclamationmark")
                .foregroundStyle(UnhogTheme.destructive)
                .help(commandError(session))
        }
    }

    private func commandError(
        _ session: AgentSessionSnapshot
    ) -> String {
        guard
            case let .failed(message) = store.status(
                for: session.id
            )
        else {
            return ""
        }
        return message
    }

    private var draftIsEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func contextPercent(
        _ session: AgentSessionSnapshot
    ) -> String {
        "\(Int((session.contextShare * 100).rounded()))%"
    }

    private func openWorkingDirectory(
        _ session: AgentSessionSnapshot
    ) {
        guard let path = session.workingDirectory else { return }
        NSWorkspace.shared.open(
            URL(filePath: path, directoryHint: .isDirectory)
        )
    }
}

private struct ThreadRow: View {
    let session: AgentSessionSnapshot
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                AgentProviderMark(
                    provider: session.provider,
                    size: 16,
                    isWorking: session.freshness == .updating
                )
                .frame(width: 17)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                    Text(activity)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if session.freshness == .updating {
                    Circle()
                        .fill(UnhogTheme.healthy)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 7)
            .frame(minHeight: 36)
            .background(
                isSelected
                    ? UnhogTheme.surfaceHover
                    : isHovered
                        ? UnhogTheme.surface.opacity(0.62)
                        : Color.clear
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var activity: String {
        session.latestActivity?.title
            ?? session.projectName
            ?? session.model
            ?? "Idle"
    }
}

private struct ProjectHeader: View {
    let project: AgentProjectGroup

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder")
                .font(.system(size: 8, weight: .medium))
            Text(project.name)
                .font(.system(size: 8, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Text("\(project.sessions.count)")
                .font(.system(size: 7, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 7)
        .frame(height: 20)
    }
}

private struct TimelineEntryView: View {
    let entry: AgentTimelineEntry
    let nestedSession: AgentSessionSnapshot?

    var body: some View {
        switch entry.kind {
        case .toolCall, .toolResult:
            ToolEntryView(entry: entry)
        case .subagent:
            NestedAgentEntryView(
                entry: entry,
                session: nestedSession
            )
        default:
            MessageEntryView(entry: entry)
        }
    }
}

private struct BackgroundAgentEntryView: View {
    let session: AgentSessionSnapshot

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    AgentProviderMark(
                        provider: .claude,
                        size: 16,
                        isWorking: session.freshness == .updating
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Background work")
                            .font(.system(size: 9, weight: .semibold))
                        Text(
                            session.latestActivity?.title
                                ?? "Waiting for activity"
                        )
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                    Image(
                        systemName: isExpanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(session.timeline.suffix(4)) { entry in
                        TimelineEntryView(
                            entry: entry,
                            nestedSession: nil
                        )
                    }
                }
                .padding(.leading, 23)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(9)
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct MessageEntryView: View {
    let entry: AgentTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.kind == .userMessage ? "You" : "Agent")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(
                    entry.kind == .userMessage
                        ? UnhogTheme.selection
                        : .secondary
                )

            if let detail = entry.detail, !detail.isEmpty {
                MarkdownText(source: detail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToolEntryView: View {
    let entry: AgentTimelineEntry

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard entry.toolDetails != nil else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: toolSymbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(UnhogTheme.surfaceHover)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 7,
                                style: .continuous
                            )
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.title)
                            .font(.system(size: 10, weight: .medium))
                        if let detail = entry.detail, !detail.isEmpty {
                            Text(detail)
                                .font(
                                    .system(
                                        size: 8,
                                        design: .monospaced
                                    )
                                )
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)

                    if entry.toolDetails != nil {
                        Image(
                            systemName: isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 8)
                .frame(minHeight: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded, let details = entry.toolDetails {
                Divider()
                    .opacity(0.35)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        ToolMetadata("Call", value: details.callID)
                        ToolMetadata(
                            "Time",
                            value: entry.timestamp.formatted(
                                date: .omitted,
                                time: .standard
                            )
                        )
                    }

                    if let input = details.input, !input.isEmpty {
                        ToolDetailBlock(title: "Input", value: input)
                    }
                    if let output = details.output, !output.isEmpty {
                        ToolDetailBlock(title: "Output", value: output)
                    }
                }
                .padding(9)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(UnhogTheme.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private var toolSymbol: String {
        let title = entry.title.lowercased()
        if title.contains("read") { return "doc.text" }
        if title.contains("search") { return "magnifyingglass" }
        if title.contains("edit") || title.contains("patch") {
            return "pencil"
        }
        return "terminal"
    }

    private var stateColor: Color {
        switch entry.state {
        case .working:
            UnhogTheme.warning
        case .completed:
            UnhogTheme.healthy
        case .failed:
            UnhogTheme.destructive
        case .informational:
            .secondary
        }
    }
}

private struct ToolMetadata: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.system(size: 7, design: .monospaced))
        .lineLimit(1)
    }
}

private struct ToolDetailBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        value,
                        forType: .string
                    )
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 7, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(InlineActionStyle(compact: true))
                .accessibilityLabel("Copy \(title.lowercased())")
            }

            ScrollView(
                [.horizontal, .vertical],
                showsIndicators: true
            ) {
                Text(value)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .frame(maxHeight: 220)
            .padding(7)
            .background(UnhogTheme.surfaceHover)
            .clipShape(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
    }
}

private struct NestedAgentEntryView: View {
    let entry: AgentTimelineEntry
    let session: AgentSessionSnapshot?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                guard session != nil else { return }
                isExpanded.toggle()
            } label: {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(UnhogTheme.ram)
                        .frame(width: 3, height: 24)

                    Image(
                        systemName:
                            "point.3.connected.trianglepath.dotted"
                    )
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(UnhogTheme.ram)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.detail ?? "Sub-agent")
                            .font(.system(size: 9, weight: .semibold))
                        Text(session?.latestActivity?.title ?? entry.title)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if session != nil {
                        Image(
                            systemName: isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded, let session {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(session.timeline.suffix(4)) { childEntry in
                        TimelineEntryView(
                            entry: childEntry,
                            nestedSession: nil
                        )
                    }
                }
                .padding(.leading, 18)
                .transition(.opacity)
            }
        }
        .padding(.leading, 7)
    }
}

private struct MarkdownText: View {
    let source: String

    var body: some View {
        Text(attributed)
            .font(.system(size: 10))
            .foregroundStyle(.primary)
            .lineSpacing(3)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        (try? AttributedString(
            markdown: source,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(source)
    }
}

private struct ModelControl: View {
    @ObservedObject var store: AgentStore
    let session: AgentSessionSnapshot

    var body: some View {
        FluidDropdown(
            width: 230,
            triggerStyle: .standard
        ) {
            Text(shortModel)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
        } content: {
            FluidDropdownSectionLabel("Model for next turn")

            TextField(
                "Model ID",
                text: Binding(
                    get: { store.preferredModel(for: session) },
                    set: {
                        store.setPreferredModel(
                            $0,
                            for: session.provider
                        )
                    }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 9, design: .monospaced))
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(UnhogTheme.surfaceHover)
            .clipShape(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
            )

            ForEach(
                store.models(for: session.provider),
                id: \.self
            ) { model in
                FluidDropdownAction(
                    model,
                    systemImage: model
                        == store.preferredModel(for: session)
                        ? "checkmark"
                        : "cpu"
                ) {
                    store.setPreferredModel(
                        model,
                        for: session.provider
                    )
                }
            }
        }
    }

    private var shortModel: String {
        let model = store.preferredModel(for: session)
        return model.isEmpty ? "model" : model
    }
}
