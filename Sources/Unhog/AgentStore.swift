import Combine
import Foundation
import UnhogCore

@MainActor
final class AgentStore: ObservableObject {
    @Published private(set) var sessions: [AgentSessionSnapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let scanner: AgentSessionScanner
    private var refreshTask: Task<Void, Never>?

    init(scanner: AgentSessionScanner = AgentSessionScanner()) {
        self.scanner = scanner
    }

    func startRefreshing() {
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

                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit {
        refreshTask?.cancel()
    }

    private func apply(_ outcome: AgentLoadOutcome) {
        isLoading = false
        switch outcome {
        case let .loaded(sessions):
            self.sessions = sessions
            errorMessage = nil
        case let .failed(message):
            errorMessage = message
        }
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
