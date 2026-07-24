import Combine
import Foundation
import UnhogCore

enum AgentCommandStatus: Equatable {
    case idle
    case sending
    case sent
    case failed(String)
}

@MainActor
final class AgentStore: ObservableObject {
    @Published private(set) var sessions: [AgentSessionSnapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedSessionID: String?
    @Published private(set) var commandStatus: [String: AgentCommandStatus] =
        [:]
    @Published private var preferredModels: [AgentProvider: String] = [:]

    private let scanner: AgentSessionScanner
    private var refreshTask: Task<Void, Never>?
    private var refreshObserverCount = 0

    init(scanner: AgentSessionScanner = AgentSessionScanner()) {
        self.scanner = scanner
    }

    var selectedSession: AgentSessionSnapshot? {
        guard let selectedSessionID else { return rootSessions.first }
        return rootSessions.first { $0.id == selectedSessionID }
            ?? rootSessions.first
    }

    var rootSessions: [AgentSessionSnapshot] {
        let childIDs = Set(
            sessions.flatMap { session in
                session.subagents.map {
                    "\(session.provider.rawValue):\($0.id)"
                }
            }
        )
        return sessions.filter {
            !childIDs.contains($0.id) && !isClaudeBackgroundSession($0)
        }
    }

    func select(_ sessionID: String) {
        selectedSessionID = sessionID
    }

    func nestedSession(
        for timelineEntry: AgentTimelineEntry
    ) -> AgentSessionSnapshot? {
        guard let relatedSessionID = timelineEntry.relatedSessionID else {
            return nil
        }
        return sessions.first { $0.id == relatedSessionID }
    }

    func backgroundSessions(
        for parent: AgentSessionSnapshot
    ) -> [AgentSessionSnapshot] {
        guard parent.provider == .claude else { return [] }
        return sessions.filter {
            isClaudeBackgroundSession($0)
                && $0.projectName == parent.projectName
        }
    }

    func startRefreshing() {
        refreshObserverCount += 1
        guard refreshTask == nil else { return }
        isLoading = sessions.isEmpty
        let scanner = scanner
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let outcome = await Task.detached(priority: .utility) {
                    AgentLoadOutcome {
                        try scanner.scan()
                    }
                }.value
                guard !Task.isCancelled else { return }
                self?.apply(outcome)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopRefreshing() {
        refreshObserverCount = max(0, refreshObserverCount - 1)
        guard refreshObserverCount == 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }

    func models(for provider: AgentProvider) -> [String] {
        Array(
            Set(
                sessions
                    .filter { $0.provider == provider }
                    .compactMap(\.model)
            )
        )
        .sorted()
    }

    func preferredModel(for session: AgentSessionSnapshot) -> String {
        preferredModels[session.provider] ?? session.model ?? ""
    }

    func setPreferredModel(
        _ model: String,
        for provider: AgentProvider
    ) {
        preferredModels[provider] = model
    }

    func status(for sessionID: String) -> AgentCommandStatus {
        commandStatus[sessionID] ?? .idle
    }

    func send(
        _ prompt: String,
        to session: AgentSessionSnapshot
    ) {
        let cleanPrompt = prompt.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanPrompt.isEmpty,
              status(for: session.id) != .sending else {
            return
        }

        let model = preferredModel(for: session)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let command = AgentCommandBuilder.command(
            provider: session.provider,
            sessionID: session.id,
            prompt: cleanPrompt,
            model: model.isEmpty ? nil : model
        )
        commandStatus[session.id] = .sending
        let directory = session.workingDirectory

        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                AgentCommandExecutor.run(
                    command,
                    workingDirectory: directory
                )
            }.value
            guard let self else { return }
            switch result {
            case .success:
                commandStatus[session.id] = .sent
            case let .failure(message):
                commandStatus[session.id] = .failed(message)
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private func apply(_ outcome: AgentLoadOutcome) {
        isLoading = false
        switch outcome {
        case let .loaded(sessions):
            self.sessions = sessions
            if selectedSessionID == nil
                || !rootSessions.contains(where: {
                    $0.id == selectedSessionID
                }) {
                selectedSessionID = rootSessions.first?.id
            }
            errorMessage = nil
        case let .failed(message):
            errorMessage = message
        }
    }

    private func isClaudeBackgroundSession(
        _ session: AgentSessionSnapshot
    ) -> Bool {
        session.provider == .claude
            && session.isBackgroundAgent
    }
}

private enum AgentCommandResult: Sendable {
    case success
    case failure(String)
}

private enum AgentCommandExecutor {
    static func run(
        _ command: AgentCommand,
        workingDirectory: String?
    ) -> AgentCommandResult {
        guard let executable = executableURL(
            named: command.executableName
        ) else {
            return .failure(
                "\(command.executableName) CLI was not found."
            )
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = command.arguments
        if let workingDirectory,
           FileManager.default.fileExists(atPath: workingDirectory) {
            process.currentDirectoryURL = URL(
                filePath: workingDirectory,
                directoryHint: .isDirectory
            )
        }
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            let data = try errorPipe.fileHandleForReading.readToEnd()
                ?? Data()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success
            }
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(
                message?.isEmpty == false
                    ? String(message!.prefix(240))
                    : "The agent command exited with an error."
            )
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func executableURL(named name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [String]
        switch name {
        case "codex":
            candidates = [
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex",
                "\(home)/.local/bin/codex"
            ]
        case "claude":
            candidates = [
                "\(home)/.local/bin/claude",
                "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude"
            ]
        default:
            candidates = []
        }
        guard let path = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            return nil
        }
        return URL(filePath: path)
    }
}

private enum AgentLoadOutcome: Sendable {
    case loaded([AgentSessionSnapshot])
    case failed(String)

    init(_ operation: () throws -> [AgentSessionSnapshot]) {
        do {
            self = .loaded(try operation())
        } catch {
            self = .failed(error.localizedDescription)
        }
    }
}
