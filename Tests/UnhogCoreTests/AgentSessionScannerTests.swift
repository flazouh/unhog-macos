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
        #expect(session.contextTokens == 74_271)
        #expect(session.contextWindowTokens == 200_000)
        #expect(session.contextWindowConfidence == .estimated)
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

    func writeCodex(_ contents: String) throws {
        try write(
            contents,
            to: codex.appending(path: "rollout-codex-1.jsonl")
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
