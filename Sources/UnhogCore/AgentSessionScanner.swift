import Foundation

public enum AgentProvider: String, Equatable, Hashable, Sendable {
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
    public let isBackgroundAgent: Bool
    public let timeline: [AgentTimelineEntry]
    public let subagents: [AgentSubagentSnapshot]

    public var contextShare: Double {
        guard contextWindowTokens > 0 else { return 0 }
        return min(
            1,
            Double(contextTokens) / Double(contextWindowTokens)
        )
    }

    public var latestActivity: AgentTimelineEntry? {
        timeline.last
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

        let parsed = candidates
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

        var seenSessionIDs: Set<String> = []
        return parsed.filter {
            seenSessionIDs.insert($0.id).inserted
        }
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
        var timeline: [AgentTimelineEntry] = []
        var toolTimelineIndexByID: [String: Int] = [:]
        var subagentsByID: [String: AgentSubagentSnapshot] = [:]

        for (index, object) in chunks.objects.enumerated() {
            let type = string(object["type"])
            let payload = dictionary(object["payload"])
            let timestamp = date(object["timestamp"])
                ?? candidate.modifiedAt

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
            case "event_msg"
                where string(payload["type"]) == "user_message":
                if let message = string(payload["message"]) {
                    timeline.append(
                        entry(
                            id: "codex-user-\(index)",
                            kind: .userMessage,
                            title: "You",
                            detail: message,
                            timestamp: timestamp
                        )
                    )
                }
            case "event_msg"
                where string(payload["type"]) == "agent_message":
                if let message = string(payload["message"]),
                   isDisplayableAgentMessage(message) {
                    timeline.append(
                        entry(
                            id: "codex-agent-\(index)",
                            kind: .assistantMessage,
                            title: "Agent replied",
                            detail: message,
                            timestamp: timestamp
                        )
                    )
                }
            case "response_item"
                where string(payload["type"]) == "function_call"
                    || string(payload["type"]) == "custom_tool_call"
                    || string(payload["type"]) == "tool_search_call":
                let name = string(payload["name"])
                    ?? string(payload["tool"])
                    ?? "Tool"
                let callID = string(payload["call_id"])
                    ?? "codex-tool-\(index)"
                timeline.append(
                    AgentTimelineEntry(
                        id: callID,
                        kind: .toolCall,
                        title: humanized(name),
                        detail: summarizedArguments(payload),
                        timestamp: timestamp,
                        state: .working,
                        toolDetails: AgentToolDetails(
                            callID: callID,
                            input: detailedArguments(payload)
                        )
                    )
                )
                toolTimelineIndexByID[callID] = timeline.count - 1
            case "response_item"
                where string(payload["type"]) == "function_call_output"
                    || string(payload["type"]) == "custom_tool_call_output"
                    || string(payload["type"]) == "tool_search_output":
                if let callID = string(payload["call_id"]),
                   let timelineIndex = toolTimelineIndexByID[callID] {
                    timeline[timelineIndex].state = .completed
                    var details = timeline[timelineIndex].toolDetails
                    details?.output = detailedValue(payload["output"])
                    timeline[timelineIndex].toolDetails = details
                }
            case "event_msg"
                where string(payload["type"]) == "sub_agent_activity":
                guard let threadID = string(
                    payload["agent_thread_id"]
                ) else {
                    break
                }
                let path = string(payload["agent_path"])
                    ?? "/subagent"
                let activity = string(payload["kind"]) ?? "interacted"
                let activityDate = millisecondsDate(
                    payload["occurred_at_ms"]
                ) ?? timestamp
                let snapshot = AgentSubagentSnapshot(
                    id: threadID,
                    name: humanized(
                        URL(filePath: path).lastPathComponent
                    ),
                    path: path,
                    state: subagentState(activity),
                    updatedAt: activityDate
                )
                subagentsByID[threadID] = snapshot
                timeline.append(
                    AgentTimelineEntry(
                        id: "codex-subagent-\(index)",
                        kind: .subagent,
                        title: "Sub-agent \(activity)",
                        detail: snapshot.name,
                        timestamp: activityDate,
                        state: activity == "completed"
                            ? .completed
                            : .working,
                        relatedSessionID: "codex:\(threadID)"
                    )
                )
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
            freshness: freshness(candidate, now: now),
            isBackgroundAgent: false,
            timeline: Array(timeline.suffix(160)),
            subagents: subagentsByID.values.sorted {
                $0.updatedAt > $1.updatedAt
            }
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
        var timeline: [AgentTimelineEntry] = []
        var toolTimelineIndexByID: [String: Int] = [:]

        for (index, object) in chunks.tailObjects.enumerated() {
            let objectType = string(object["type"])
            sessionID = string(object["sessionId"])
                ?? string(object["session_id"])
                ?? sessionID
            cwd = string(object["cwd"]) ?? cwd
            sessionKind = string(object["sessionKind"]) ?? sessionKind
            let timestamp = date(object["timestamp"])
                ?? candidate.modifiedAt
            let message = dictionary(object["message"])

            if objectType == "user" {
                let content = message["content"] as? [Any] ?? []
                for rawBlock in content {
                    let block = dictionary(rawBlock)
                    guard string(block["type"]) == "tool_result",
                          let toolID = string(block["tool_use_id"]),
                          let timelineIndex =
                              toolTimelineIndexByID[toolID] else {
                        continue
                    }
                    timeline[timelineIndex].state =
                        block["is_error"] as? Bool == true
                            ? .failed
                            : .completed
                    var details = timeline[timelineIndex].toolDetails
                    details?.output = detailedValue(block["content"])
                    timeline[timelineIndex].toolDetails = details
                }
                if let detail = claudeText(message["content"]) {
                    timeline.append(
                        entry(
                            id: "claude-user-\(index)",
                            kind: .userMessage,
                            title: "You",
                            detail: detail,
                            timestamp: timestamp
                        )
                    )
                }
                continue
            }

            guard objectType == "assistant" else { continue }
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

            let content = message["content"] as? [Any] ?? []
            for (contentIndex, rawBlock) in content.enumerated() {
                let block = dictionary(rawBlock)
                switch string(block["type"]) {
                case "text":
                    if let text = string(block["text"]) {
                        timeline.append(
                            entry(
                                id: "claude-agent-\(index)-\(contentIndex)",
                                kind: .assistantMessage,
                                title: "Agent replied",
                                detail: text,
                                timestamp: timestamp
                            )
                        )
                    }
                case "tool_use":
                    let name = string(block["name"]) ?? "Tool"
                    let toolID = string(block["id"])
                        ?? "claude-tool-\(index)-\(contentIndex)"
                    timeline.append(
                        AgentTimelineEntry(
                            id: toolID,
                            kind: .toolCall,
                            title: humanized(name),
                            detail: summarizedInput(
                                dictionary(block["input"])
                            ),
                            timestamp: timestamp,
                            state: .working,
                            toolDetails: AgentToolDetails(
                                callID: toolID,
                                input: detailedValue(block["input"])
                            )
                        )
                    )
                    toolTimelineIndexByID[toolID] = timeline.count - 1
                default:
                    break
                }
            }
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
            freshness: freshness(candidate, now: now),
            isBackgroundAgent: sessionKind == "bg",
            timeline: Array(timeline.suffix(160)),
            subagents: []
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

private func date(_ value: Any?) -> Date? {
    guard let value = string(value) else { return nil }
    return ISO8601DateFormatter().date(from: value)
}

private func millisecondsDate(_ value: Any?) -> Date? {
    guard let milliseconds = (value as? NSNumber)?.doubleValue else {
        return nil
    }
    return Date(timeIntervalSince1970: milliseconds / 1_000)
}

private func entry(
    id: String,
    kind: AgentTimelineKind,
    title: String,
    detail: String,
    timestamp: Date
) -> AgentTimelineEntry {
    AgentTimelineEntry(
        id: id,
        kind: kind,
        title: title,
        detail: clean(detail),
        timestamp: timestamp,
        state: .informational
    )
}

private func clean(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func humanized(_ value: String) -> String {
    value
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
}

private func subagentState(_ activity: String) -> AgentSubagentState {
    switch activity {
    case "completed", "closed":
        .completed
    case "waiting", "idle":
        .waiting
    default:
        .working
    }
}

private func summarizedArguments(_ payload: [String: Any]) -> String? {
    guard let arguments = string(payload["arguments"]),
          let data = arguments.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any] else {
        return nil
    }
    return summarizedInput(dictionary)
}

private func detailedArguments(_ payload: [String: Any]) -> String? {
    if let arguments = string(payload["arguments"]) {
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(
                with: data
              ) else {
            return clean(arguments)
        }
        return detailedValue(object)
    }
    return detailedValue(
        payload["input"]
            ?? payload["query"]
            ?? payload["arguments"]
    )
}

private func detailedValue(_ value: Any?) -> String? {
    guard let value else { return nil }
    if let value = value as? String {
        return clean(value)
    }
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
          ) else {
        return String(describing: value)
    }
    return String(data: data, encoding: .utf8)
}

private func summarizedInput(_ input: [String: Any]) -> String? {
    let keys = [
        "cmd",
        "file_path",
        "path",
        "query",
        "q",
        "target",
        "description"
    ]
    for key in keys {
        guard let value = input[key] as? String, !value.isEmpty else {
            continue
        }
        if key == "file_path" || key == "path" {
            return URL(filePath: value).lastPathComponent
        }
        return clean(value)
    }
    return nil
}

private func claudeText(_ value: Any?) -> String? {
    if let string = string(value) {
        return clean(string)
    }
    guard let blocks = value as? [Any] else { return nil }
    let texts = blocks.compactMap { block -> String? in
        let dictionary = dictionary(block)
        guard string(dictionary["type"]) == "text" else {
            return nil
        }
        return string(dictionary["text"])
    }
    guard !texts.isEmpty else { return nil }
    return clean(texts.joined(separator: "\n"))
}

private func isDisplayableAgentMessage(_ message: String) -> Bool {
    let value = clean(message)
    guard !value.isEmpty else { return false }
    if value.hasPrefix("{\"outcome\":")
        || value.hasPrefix("{\"status\":") {
        return false
    }
    return true
}
