import Foundation

public enum AgentTimelineKind: Equatable, Sendable {
    case userMessage
    case assistantMessage
    case toolCall
    case toolResult
    case subagent
    case system
}

public enum AgentTimelineState: Equatable, Sendable {
    case working
    case completed
    case failed
    case informational
}

public struct AgentToolDetails: Equatable, Sendable {
    public let callID: String
    public let input: String?
    public var output: String?

    public init(
        callID: String,
        input: String?,
        output: String? = nil
    ) {
        self.callID = callID
        self.input = input
        self.output = output
    }
}

public struct AgentProjectGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let sessions: [AgentSessionSnapshot]

    public init(
        name: String,
        sessions: [AgentSessionSnapshot]
    ) {
        id = name
        self.name = name
        self.sessions = sessions
    }
}

public enum AgentSessionOrganizer {
    public static func projects(
        _ sessions: [AgentSessionSnapshot]
    ) -> [AgentProjectGroup] {
        Dictionary(grouping: sessions) { session in
            guard let projectName = session.projectName,
                !projectName.isEmpty
            else {
                return "Other"
            }
            return projectName
        }
        .map { name, sessions in
            AgentProjectGroup(
                name: name,
                sessions: sessions.sorted {
                    $0.updatedAt > $1.updatedAt
                }
            )
        }
        .sorted { left, right in
            let leftUpdate =
                left.sessions.first?.updatedAt
                ?? .distantPast
            let rightUpdate =
                right.sessions.first?.updatedAt
                ?? .distantPast
            if leftUpdate == rightUpdate {
                return left.name.localizedCaseInsensitiveCompare(
                    right.name
                ) == .orderedAscending
            }
            return leftUpdate > rightUpdate
        }
    }
}

public struct AgentTimelineEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: AgentTimelineKind
    public let title: String
    public let detail: String?
    public let timestamp: Date
    public var state: AgentTimelineState
    public let relatedSessionID: String?
    public var toolDetails: AgentToolDetails?

    public init(
        id: String,
        kind: AgentTimelineKind,
        title: String,
        detail: String?,
        timestamp: Date,
        state: AgentTimelineState,
        relatedSessionID: String? = nil,
        toolDetails: AgentToolDetails? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
        self.state = state
        self.relatedSessionID = relatedSessionID
        self.toolDetails = toolDetails
    }
}

public enum AgentSubagentState: Equatable, Sendable {
    case working
    case waiting
    case completed
}

public struct AgentSubagentSnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let state: AgentSubagentState
    public let updatedAt: Date

    public init(
        id: String,
        name: String,
        path: String,
        state: AgentSubagentState,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.state = state
        self.updatedAt = updatedAt
    }
}

public struct AgentCommand: Equatable, Sendable {
    public let executableName: String
    public let arguments: [String]

    public init(executableName: String, arguments: [String]) {
        self.executableName = executableName
        self.arguments = arguments
    }
}

public enum AgentCommandBuilder {
    public static func command(
        provider: AgentProvider,
        sessionID: String,
        prompt: String,
        model: String?
    ) -> AgentCommand {
        let rawID =
            sessionID.split(
                separator: ":",
                maxSplits: 1
            ).last.map(String.init) ?? sessionID

        switch provider {
        case .codex:
            var arguments = ["exec", "resume"]
            if let model, !model.isEmpty {
                arguments += ["--model", model]
            }
            arguments += [rawID, prompt]
            return AgentCommand(
                executableName: "codex",
                arguments: arguments
            )
        case .claude:
            var arguments = ["--print", "--resume", rawID]
            if let model, !model.isEmpty {
                arguments += ["--model", model]
            }
            arguments.append(prompt)
            return AgentCommand(
                executableName: "claude",
                arguments: arguments
            )
        }
    }
}
