import Combine
import Foundation
import UnhogCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderUsageSnapshot] = []
    @Published private(set) var isRefreshing = false

    private let scanner: UsageScanner
    private var refreshTask: Task<Void, Never>?
    private var observerCount = 0

    init(scanner: UsageScanner = UsageScanner()) {
        self.scanner = scanner
    }

    func startRefreshing() {
        observerCount += 1
        guard refreshTask == nil else { return }
        isRefreshing = snapshots.isEmpty
        let scanner = scanner
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let snapshots = await scanner.scan()
                guard !Task.isCancelled else { return }
                self?.snapshots = snapshots
                self?.isRefreshing = false
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func stopRefreshing() {
        observerCount = max(0, observerCount - 1)
        guard observerCount == 0 else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let scanner = scanner
        Task { [weak self] in
            let snapshots = await scanner.scan()
            guard let self else { return }
            self.snapshots = snapshots
            self.isRefreshing = false
        }
    }

    func applyPreviewFixture() {
        let now = Date()
        snapshots = [
            ProviderUsageSnapshot(
                provider: .claude,
                plan: "Max 5x",
                windows: [
                    UsageWindow(
                        id: "session",
                        label: "Session",
                        usedPercent: 68,
                        resetsAt: now.addingTimeInterval(2_140)
                    ),
                    UsageWindow(
                        id: "weekly",
                        label: "Weekly",
                        usedPercent: 41,
                        resetsAt: now.addingTimeInterval(218_000)
                    ),
                ],
                today: LocalUsageTotals(
                    inputTokens: 1_820_000,
                    outputTokens: 84_000,
                    turnCount: 97
                ),
                lastSevenDays: LocalUsageTotals(
                    inputTokens: 8_420_000,
                    outputTokens: 422_000,
                    turnCount: 614
                ),
                lastThirtyDays: LocalUsageTotals(
                    inputTokens: 31_200_000,
                    outputTokens: 1_640_000,
                    turnCount: 2_480
                ),
                refreshedAt: now,
                connectionState: .connected
            ),
            ProviderUsageSnapshot(
                provider: .codex,
                plan: "Plus",
                windows: [
                    UsageWindow(
                        id: "session",
                        label: "Session",
                        usedPercent: 23,
                        resetsAt: now.addingTimeInterval(8_200)
                    ),
                    UsageWindow(
                        id: "weekly",
                        label: "Weekly",
                        usedPercent: 56,
                        resetsAt: now.addingTimeInterval(328_000)
                    ),
                ],
                creditBalance: 796,
                today: LocalUsageTotals(
                    inputTokens: 3_140_000,
                    outputTokens: 126_000,
                    turnCount: 142
                ),
                lastSevenDays: LocalUsageTotals(
                    inputTokens: 12_900_000,
                    outputTokens: 620_000,
                    turnCount: 840
                ),
                lastThirtyDays: LocalUsageTotals(
                    inputTokens: 49_800_000,
                    outputTokens: 2_120_000,
                    turnCount: 3_220
                ),
                refreshedAt: now,
                connectionState: .connected
            ),
        ]
        isRefreshing = false
    }

    deinit {
        refreshTask?.cancel()
    }
}
