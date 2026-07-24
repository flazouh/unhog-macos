import Foundation
import Testing
@testable import UnhogCore

struct AgentSessionScannerTests {
    @Test
    func codexSessionReportsExactContextWindowUsage() throws {
        let fixture = try AgentFixture()
        defer { fixture.remove() }

        try fixture.writeCodex(
            """
            {"type":"session_meta","payload":{"id":"codex-1","cwd":"/tmp/Unhog","agent_nickname":"Euler","agent_role":"default","originator":"Codex Desktop"}}
            {"type":"event_msg","payload":{"type":"task_started","model_context_window":258400}}
            {"type":"turn_context","payload":{"model":"gpt-5.6-sol","cwd":"/tmp/Unhog"}}
            {"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":151839,"output_tokens":621},"model_context_window":258400}}}
            """
        )

        let sessions = try fixture.scanner.scan(now: Date())
        let session = try #require(
            sessions.first { $0.id == "codex:codex-1" }
        )

        #expect(session.provider == .codex)
        #expect(session.name == "Euler")
        #expect(session.projectName == "Unhog")
        #expect(session.model == "gpt-5.6-sol")
        #expect(session.contextTokens == 151_839)
        #expect(session.contextWindowTokens == 258_400)
        #expect(session.contextWindowConfidence == .exact)
    }

    @Test
    func codexSessionExposesLiveToolsMessagesAndSubagents() throws {
        let fixture = try AgentFixture()
        defer { fixture.remove() }

        try fixture.writeCodex(
            """
            {"timestamp":"2026-07-24T10:00:00Z","type":"session_meta","payload":{"id":"codex-1","cwd":"/tmp/Unhog","agent_nickname":"Euler"}}
            {"timestamp":"2026-07-24T10:00:01Z","type":"event_msg","payload":{"type":"user_message","message":"Find the memory leak"}}
            {"timestamp":"2026-07-24T10:00:02Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","call_id":"call-1","arguments":"{\\"cmd\\":\\"ps aux\\"}"}}
            {"timestamp":"2026-07-24T10:00:02Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call-1","output":"Process list"}}
            {"timestamp":"2026-07-24T10:00:03Z","type":"event_msg","payload":{"type":"sub_agent_activity","kind":"started","agent_path":"/root/memory_probe","agent_thread_id":"child-1","occurred_at_ms":1784887203000}}
            {"timestamp":"2026-07-24T10:00:03Z","type":"event_msg","payload":{"type":"agent_message","message":"{\\"outcome\\":\\"allow\\"}"}}
            {"timestamp":"2026-07-24T10:00:04Z","type":"event_msg","payload":{"type":"agent_message","message":"The spike comes from a browser worker."}}
            """
        )

        let session = try #require(
            fixture.scanner.scan(now: Date()).first
        )

        #expect(session.timeline.map(\.kind) == [
            .userMessage,
            .toolCall,
            .subagent,
            .assistantMessage
        ])
        #expect(session.timeline[1].title == "exec command")
        #expect(session.timeline[1].detail == "ps aux")
        #expect(session.timeline[1].state == .completed)
        #expect(session.timeline[1].toolDetails?.callID == "call-1")
        #expect(
            session.timeline[1].toolDetails?.input
                == """
                {
                  "cmd" : "ps aux"
                }
                """
        )
        #expect(
            session.timeline[1].toolDetails?.output == "Process list"
        )
        #expect(
            session.timeline[2].relatedSessionID
                == "codex:child-1"
        )
        #expect(session.subagents == [
            AgentSubagentSnapshot(
                id: "child-1",
                name: "memory probe",
                path: "/root/memory_probe",
                state: .working,
                updatedAt: Date(timeIntervalSince1970: 1_784_887_203)
            )
        ])
        #expect(session.latestActivity?.title == "Agent replied")
    }

    @Test
    func scannerKeepsOnlyTheNewestFileForOneSessionID() throws {
        let fixture = try AgentFixture()
        defer { fixture.remove() }

        try fixture.writeCodex(
            """
            {"type":"session_meta","payload":{"id":"same-thread","cwd":"/tmp/Old"}}
            """,
            named: "older.jsonl"
        )
        try fixture.writeCodex(
            """
            {"type":"session_meta","payload":{"id":"same-thread","cwd":"/tmp/New"}}
            """,
            named: "newer.jsonl"
        )

        let sessions = try fixture.scanner.scan(now: Date())
        #expect(sessions.count == 1)
        #expect(sessions[0].id == "codex:same-thread")
    }

    @Test
    func claudeSessionReportsCurrentContextAsAnEstimate() throws {
        let fixture = try AgentFixture()
        defer { fixture.remove() }

        try fixture.writeClaude(
            """
            {"type":"assistant","sessionId":"claude-1","cwd":"/tmp/Unhog","sessionKind":"bg","message":{"model":"claude-fable-5","usage":{"input_tokens":1,"cache_creation_input_tokens":2051,"cache_read_input_tokens":70286,"output_tokens":1933}}}
            """
        )

        let sessions = try fixture.scanner.scan(now: Date())
        let session = try #require(
            sessions.first { $0.id == "claude:claude-1" }
        )

        #expect(session.provider == .claude)
        #expect(session.projectName == "Unhog")
        #expect(session.model == "claude-fable-5")
        #expect(session.isBackgroundAgent)
        #expect(session.contextTokens == 74_271)
        #expect(session.contextWindowTokens == 200_000)
        #expect(session.contextWindowConfidence == .estimated)
    }

    @Test
    func claudeSessionExposesToolCallsAndTranscriptMessages() throws {
        let fixture = try AgentFixture()
        defer { fixture.remove() }

        try fixture.writeClaude(
            """
            {"type":"user","sessionId":"claude-1","cwd":"/tmp/Unhog","timestamp":"2026-07-24T10:00:00Z","message":{"role":"user","content":"Inspect the app"}}
            {"type":"assistant","sessionId":"claude-1","cwd":"/tmp/Unhog","timestamp":"2026-07-24T10:00:01Z","message":{"model":"claude-fable-5","usage":{"input_tokens":10,"output_tokens":2},"content":[{"type":"tool_use","id":"tool-1","name":"Read","input":{"file_path":"/tmp/Unhog/Package.swift"}},{"type":"text","text":"I found the package."}]}}
            {"type":"user","sessionId":"claude-1","cwd":"/tmp/Unhog","timestamp":"2026-07-24T10:00:02Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tool-1","content":"Package contents"}]}}
            """
        )

        let session = try #require(
            fixture.scanner.scan(now: Date()).first
        )

        #expect(session.timeline.map(\.kind) == [
            .userMessage,
            .toolCall,
            .assistantMessage
        ])
        #expect(session.timeline[1].title == "Read")
        #expect(session.timeline[1].detail == "Package.swift")
        #expect(session.timeline[1].state == .completed)
        #expect(session.timeline[1].toolDetails?.callID == "tool-1")
        #expect(
            session.timeline[1].toolDetails?.input
                == """
                {
                  "file_path" : "/tmp/Unhog/Package.swift"
                }
                """
        )
        #expect(
            session.timeline[1].toolDetails?.output
                == "Package contents"
        )
        #expect(session.timeline[2].detail == "I found the package.")
        #expect(!session.isBackgroundAgent)
    }

    @Test
    func commandBuilderResumesTheSelectedProviderAndModel() {
        let codex = AgentCommandBuilder.command(
            provider: .codex,
            sessionID: "codex:thread-1",
            prompt: "Continue",
            model: "gpt-5.6-sol"
        )
        #expect(codex.executableName == "codex")
        #expect(codex.arguments == [
            "exec",
            "resume",
            "--model",
            "gpt-5.6-sol",
            "thread-1",
            "Continue"
        ])

        let claude = AgentCommandBuilder.command(
            provider: .claude,
            sessionID: "claude:thread-2",
            prompt: "Review this",
            model: "claude-fable-5"
        )
        #expect(claude.executableName == "claude")
        #expect(claude.arguments == [
            "--print",
            "--resume",
            "thread-2",
            "--model",
            "claude-fable-5",
            "Review this"
        ])
    }

    @Test
    func projectOrganizerGroupsSessionsAndSortsRecentFirst() {
        let sessions = [
            session(
                id: "codex:one",
                project: "Unhog",
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            session(
                id: "claude:two",
                project: "FluentAI",
                updatedAt: Date(timeIntervalSince1970: 30)
            ),
            session(
                id: "codex:three",
                project: "Unhog",
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]

        let projects = AgentSessionOrganizer.projects(sessions)

        #expect(projects.map(\.name) == ["FluentAI", "Unhog"])
        #expect(projects[1].sessions.map(\.id) == [
            "codex:three",
            "codex:one"
        ])
    }

    private func session(
        id: String,
        project: String?,
        updatedAt: Date
    ) -> AgentSessionSnapshot {
        AgentSessionSnapshot(
            id: id,
            provider: id.hasPrefix("claude:") ? .claude : .codex,
            name: project ?? "Agent",
            projectName: project,
            workingDirectory: project.map { "/tmp/\($0)" },
            model: nil,
            contextTokens: 0,
            contextWindowTokens: 0,
            contextWindowConfidence: .exact,
            latestOutputTokens: 0,
            updatedAt: updatedAt,
            freshness: .recent,
            isBackgroundAgent: false,
            timeline: [],
            subagents: []
        )
    }
}

private struct AgentFixture {
    let root: URL
    let codex: URL
    let claude: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "unhog-agent-fixture-\(UUID().uuidString)"
        )
        codex = root.appending(path: "codex")
        claude = root.appending(path: "claude")
        try FileManager.default.createDirectory(
            at: codex,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: claude,
            withIntermediateDirectories: true
        )
    }

    var scanner: AgentSessionScanner {
        AgentSessionScanner(
            codexSessionsDirectory: codex,
            claudeProjectsDirectory: claude
        )
    }

    func writeCodex(
        _ contents: String,
        named fileName: String = "rollout-codex-1.jsonl"
    ) throws {
        try write(
            contents,
            to: codex.appending(path: fileName)
        )
    }

    func writeClaude(_ contents: String) throws {
        let project = claude.appending(path: "project")
        try FileManager.default.createDirectory(
            at: project,
            withIntermediateDirectories: true
        )
        try write(
            contents,
            to: project.appending(path: "claude-1.jsonl")
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ contents: String, to url: URL) throws {
        try Data(contents.utf8).write(to: url)
    }
}
