import Foundation

public enum AgentProvider: String, Equatable, Sendable {
    case codex
    case claude
}

public enum AgentSessionFreshness: Equatable, Sendable {
    case updating
    case recent
}

public enum AgentContextWindowConfidence: Equatable, Sendable {
    case exact
    case estimated
}

public struct AgentSessionSnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let provider: AgentProvider
    public let name: String
    public let projectName: String?
    public let workingDirectory: String?
    public let model: String?
    public let contextTokens: UInt64
    public let contextWindowTokens: UInt64
    public let contextWindowConfidence: AgentContextWindowConfidence
    public let latestOutputTokens: UInt64
    public let updatedAt: Date
    public let freshness: AgentSessionFreshness

    public var contextShare: Double {
        guard contextWindowTokens > 0 else { return 0 }
        return min(
            1,
            Double(contextTokens) / Double(contextWindowTokens)
        )
    }
}

public struct AgentSessionScanner: Sendable {
    private let codexSessionsDirectory: URL
    private let claudeProjectsDirectory: URL
    private let recentInterval: TimeInterval
    private let activeInterval: TimeInterval
    private let maximumSessionCount: Int

    public init(
        codexSessionsDirectory: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appending(path: ".codex/sessions"),
        claudeProjectsDirectory: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appending(path: ".claude/projects"),
        recentInterval: TimeInterval = 60 * 60,
        activeInterval: TimeInterval = 90,
        maximumSessionCount: Int = 12
    ) {
        self.codexSessionsDirectory = codexSessionsDirectory
        self.claudeProjectsDirectory = claudeProjectsDirectory
        self.recentInterval = recentInterval
        self.activeInterval = activeInterval
        self.maximumSessionCount = maximumSessionCount
    }

    public func scan(now: Date = Date()) throws
        -> [AgentSessionSnapshot] {
        let candidates =
            recentFiles(
                below: codexSessionsDirectory,
                provider: .codex,
                now: now
            )
            + recentFiles(
                below: claudeProjectsDirectory,
                provider: .claude,
                now: now
            )

        return candidates
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(maximumSessionCount)
            .compactMap { candidate in
                switch candidate.provider {
                case .codex:
                    try? parseCodex(candidate, now: now)
                case .claude:
                    try? parseClaude(candidate, now: now)
                }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func recentFiles(
        below root: URL,
        provider: AgentProvider,
        now: Date
    ) -> [Candidate] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [Candidate] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(
                    forKeys: Set(keys)
                  ),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate else {
                continue
            }
            let age = max(0, now.timeIntervalSince(modifiedAt))
            guard age <= recentInterval else { continue }
            candidates.append(
                Candidate(
                    url: url,
                    provider: provider,
                    modifiedAt: modifiedAt
                )
            )
        }
        return candidates
    }

    private func parseCodex(
        _ candidate: Candidate,
        now: Date
    ) throws -> AgentSessionSnapshot? {
        let chunks = try LogChunks(url: candidate.url)
        var sessionID: String?
        var nickname: String?
        var role: String?
        var cwd: String?
        var model: String?
        var contextTokens: UInt64 = 0
        var contextWindow: UInt64 = 0
        var outputTokens: UInt64 = 0

        for object in chunks.objects {
            let type = string(object["type"])
            let payload = dictionary(object["payload"])

            switch type {
            case "session_meta":
                sessionID = string(payload["id"])
                    ?? string(payload["session_id"])
                    ?? sessionID
                nickname = string(payload["agent_nickname"]) ?? nickname
                role = string(payload["agent_role"]) ?? role
                cwd = string(payload["cwd"]) ?? cwd
            case "turn_context":
                model = string(payload["model"]) ?? model
                cwd = string(payload["cwd"]) ?? cwd
            case "event_msg"
                where string(payload["type"]) == "task_started":
                contextWindow = integer(
                    payload["model_context_window"]
                ) ?? contextWindow
            case "event_msg"
                where string(payload["type"]) == "token_count":
                let info = dictionary(payload["info"])
                let usage = dictionary(info["last_token_usage"])
                contextTokens = integer(
                    usage["input_tokens"]
                ) ?? contextTokens
                outputTokens = integer(
                    usage["output_tokens"]
                ) ?? outputTokens
                contextWindow = integer(
                    info["model_context_window"]
                ) ?? contextWindow
            default:
                break
            }
        }

        guard let sessionID else { return nil }
        let projectName = projectName(from: cwd)
        return AgentSessionSnapshot(
            id: "codex:\(sessionID)",
            provider: .codex,
            name: nickname ?? role ?? projectName ?? "Codex",
            projectName: projectName,
            workingDirectory: cwd,
            model: model,
            contextTokens: contextTokens,
            contextWindowTokens: contextWindow,
            contextWindowConfidence: .exact,
            latestOutputTokens: outputTokens,
            updatedAt: candidate.modifiedAt,
            freshness: freshness(candidate, now: now)
        )
    }

    private func parseClaude(
        _ candidate: Candidate,
        now: Date
    ) throws -> AgentSessionSnapshot? {
        let chunks = try LogChunks(url: candidate.url)
        var sessionID: String?
        var cwd: String?
        var model: String?
        var sessionKind: String?
        var contextTokens: UInt64 = 0
        var outputTokens: UInt64 = 0

        for object in chunks.tailObjects {
            guard string(object["type"]) == "assistant" else {
                continue
            }
            sessionID = string(object["sessionId"])
                ?? string(object["session_id"])
                ?? sessionID
            cwd = string(object["cwd"]) ?? cwd
            sessionKind = string(object["sessionKind"]) ?? sessionKind

            let message = dictionary(object["message"])
            model = string(message["model"]) ?? model
            let usage = dictionary(message["usage"])
            let input = integer(usage["input_tokens"]) ?? 0
            let cacheCreation = integer(
                usage["cache_creation_input_tokens"]
            ) ?? 0
            let cacheRead = integer(
                usage["cache_read_input_tokens"]
            ) ?? 0
            outputTokens = integer(
                usage["output_tokens"]
            ) ?? outputTokens
            contextTokens = input
                + cacheCreation
                + cacheRead
                + outputTokens
        }

        guard let sessionID else { return nil }
        let projectName = projectName(from: cwd)
        return AgentSessionSnapshot(
            id: "claude:\(sessionID)",
            provider: .claude,
            name: sessionKind == "bg"
                ? "Claude background"
                : projectName ?? "Claude",
            projectName: projectName,
            workingDirectory: cwd,
            model: model,
            contextTokens: contextTokens,
            contextWindowTokens: 200_000,
            contextWindowConfidence: .estimated,
            latestOutputTokens: outputTokens,
            updatedAt: candidate.modifiedAt,
            freshness: freshness(candidate, now: now)
        )
    }

    private func freshness(
        _ candidate: Candidate,
        now: Date
    ) -> AgentSessionFreshness {
        now.timeIntervalSince(candidate.modifiedAt) <= activeInterval
            ? .updating
            : .recent
    }

    private func projectName(from path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(filePath: path).lastPathComponent
    }
}

private struct Candidate {
    let url: URL
    let provider: AgentProvider
    let modifiedAt: Date
}

private struct LogChunks {
    let headObjects: [[String: Any]]
    let tailObjects: [[String: Any]]
    let isSingleChunk: Bool

    init(url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()

        try handle.seek(toOffset: 0)
        let head = try handle.read(upToCount: 128 * 1_024) ?? Data()

        let tailLimit = UInt64(512 * 1_024)
        let tailOffset = fileSize > tailLimit ? fileSize - tailLimit : 0
        try handle.seek(toOffset: tailOffset)
        let tail = try handle.readToEnd() ?? Data()

        headObjects = Self.objects(
            in: head,
            dropsLeadingPartialLine: false
        )
        isSingleChunk = tailOffset == 0
        if tailOffset == 0 {
            tailObjects = headObjects
        } else {
            tailObjects = Self.objects(
                in: tail,
                dropsLeadingPartialLine: true
            )
        }
    }

    var objects: [[String: Any]] {
        isSingleChunk ? headObjects : headObjects + tailObjects
    }

    private static func objects(
        in data: Data,
        dropsLeadingPartialLine: Bool
    ) -> [[String: Any]] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }
        var lines = text.split(
            separator: "\n",
            omittingEmptySubsequences: true
        )
        if dropsLeadingPartialLine, !lines.isEmpty {
            lines.removeFirst()
        }
        return lines.compactMap { line in
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(
                    with: data
                  ) as? [String: Any] else {
                return nil
            }
            return object
        }
    }
}

private func dictionary(_ value: Any?) -> [String: Any] {
    value as? [String: Any] ?? [:]
}

private func string(_ value: Any?) -> String? {
    value as? String
}

private func integer(_ value: Any?) -> UInt64? {
    (value as? NSNumber)?.uint64Value
}
